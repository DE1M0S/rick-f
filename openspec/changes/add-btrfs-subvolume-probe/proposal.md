# Proposal

## Why

To show Btrfs snapshots, Rick first has to know which subvolume a folder lies in and which subvolumes are snapshots of it. Btrfs has no fixed snapshot folder like ZFS's `.zfs/snapshot`: a snapshot is an ordinary subvolume that can lie anywhere, linked to its source only by `parent_uuid`. The kernel has offered unprivileged ioctls for exactly this question since 2018 (`INO_LOOKUP_USER`, `GET_SUBVOL_ROOTREF`, `GET_SUBVOL_INFO`), so it can be answered without root, without `btrfs-progs` and without Snapper or Timeshift. Those ioctls need `unsafe`, which only the `platform` crate may contain. This change is that seam, on its own so the `unsafe` code gets its own review before any plugin builds on it.

## What Changes

- A new platform service, **subvolumes**, that answers three questions about local paths on Linux:
  - *What is this?* For a path: whether it lies on Btrfs and, if so, the subvolume it lies in (id, uuid, parent uuid, creation time, read-only flag, the subvolume's root folder) and the file system's id.
  - *What lies below?* The subvolumes below a folder that the user can reach, each with the same facts and its path; subvolumes the user cannot reach are skipped silently.
  - *Where is Btrfs mounted?* The mounted Btrfs file systems with each mount's subvolume id and the device it came from, read from the process's mount table.
- No root is ever needed and nothing is ever written: every call is a read.
- On macOS and Windows, and for a path that is not on Btrfs, the service answers "not Btrfs" and never fails.
- The fake platform gains a scripted version of the service, so plugins can be tested without a Btrfs file system.
- The extension API version goes up by one, because the service is part of the platform object extensions receive.
- **Out of scope:** anything a user sees (that is `add-btrfs-snapshots`); creating, deleting or renaming subvolumes (`add-btrfs-snapshot-management`); mounting anything (`add-btrfs-toplevel-mount`); quota groups, send/receive, scrub, balance, device management; WinBtrfs on Windows; the `btrfs` command line, which this change does not use.

## Capabilities

### New Capabilities

- `btrfs-subvolume-probe`: identifying the Btrfs subvolume a local path lies in, listing the reachable subvolumes below a folder, and listing the mounted Btrfs file systems, without privileges, on Linux only.

### Modified Capabilities

None.

## Impact

- **Crates touched:**
  - `platform`: a new trait in `traits.rs`, joined into the `Platform` supertrait. Implemented with `libc`/`rustix` ioctls in `linux/`, and as "unsupported" on macOS and Windows. A scripted version goes in `fake.rs`.
  - `ext`: the API version constant goes up. `ext` re-exports `platform`, so plugins see the new trait.
  - `tests`: integration tests that are opt-in on a real Btrfs.
- **Dependencies:** none new. `libc` and `rustix` are already dependencies of `platform`. Dependencies still point downward, because no crate above `platform` gains a dependency.
- **Public trait change:** the `Platform` supertrait gains one member. Every implementor in the workspace (the real platforms and the fake) implements it in the same change. Extensions compiled against the old API are refused by the version check, as for every API bump.
- **Unsafe code:** only in `platform/src/linux/`, each block with a `// SAFETY:` comment.
- **CI:** unchanged. The real-Btrfs tests are skipped without `RICK_REQUIRE_BTRFS`.
