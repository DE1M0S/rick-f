# Proposal

## Why

Ubuntu, Fedora and openSUSE install on Btrfs, and many of those systems take snapshots on a timer (Snapper, or by hand with `btrfs subvolume snapshot`). Getting a file back from one still means a shell, the right hidden folder and a guess at which snapshot holds the old version. `ext-zfs` already solves this for ZFS. This change brings the read-only half of it to Btrfs, built on the subvolume probe from `add-btrfs-subvolume-probe`, so it works without root, without `btrfs-progs` and without Snapper, on the maintainer's Fedora and on Ubuntu alike.

## What Changes

- A new feature plugin **`ext-btrfs`** (Linux only, loadable, removable like `ext-zfs`).
- It finds the snapshots of the subvolume a folder lies in. A snapshot is a read-only subvolume whose parent uuid is that subvolume's uuid, and that the user can reach below any mount of the same file system. Snapper's `.snapshots/N/snapshot` and hand-made snapshots in a reachable folder are found. Snapshots in the unmounted top level (Timeshift, btrbk on a flat layout) are not; `add-btrfs-toplevel-mount` deals with those.
- A snapshot is browsed as the local folder it is. The kernel enforces read-only, and opening, previewing and copying out work unchanged.
- A read-only `btrfs` location gives the one list no folder holds: the versions of one file across the snapshots. Older snapshots are reached through the time slider.
- Actions in the group "Btrfs": *Browse snapshots*, *Back to live folder*, *Versions* and *Restore*. They follow the ZFS actions, including *Restore*'s staging copy.
- An Info panel section *Btrfs* with the subvolume and its snapshots.
- The subvolume's snapshots become a source for the time slider.
- **Out of scope:**
  - creating, renaming or deleting snapshots (`add-btrfs-snapshot-management`);
  - anything that needs root, including the top level (`add-btrfs-toplevel-mount`);
  - Snapper's metadata (`info.xml`, descriptions, cleanup rules);
  - Timeshift's and btrbk's own catalogues;
  - received snapshots (send/receive), quotas, compression properties;
  - WinBtrfs on Windows;
  - extracting the code `ext-btrfs` shares with `ext-zfs` (restore, versions, timeline) into a common crate, which comes after both work.

## Capabilities

### New Capabilities

- `btrfs-snapshots`: finding, browsing, comparing and restoring the reachable snapshots of the Btrfs subvolume a folder lies in, and offering them to the Info panel and the time slider, without privileges.

### Modified Capabilities

None.

## Impact

- **Crates touched:**
  - `ext-btrfs` (new): depends on `ext` and `types` only, and reaches the subvolume service through `Registry::platform()`.
  - `rick`: a `btrfs` feature compiles the plugin in, like `zfs`.
  - `xtask` and `check-plugins.sh`: bundle and load the plugin.
  - `tests`: integration tests against the fake subvolume service, and an opt-in real test.
- **Dependencies:** none new outside the workspace. `chrono`, `thiserror` and `tracing` are already workspace dependencies. Dependencies still point downward: a plugin depends on `ext` and `types`, and nothing depends on the plugin except the `rick` binary.
- **API:** none of its own. It uses the API version that `add-btrfs-subvolume-probe` raises.
- **Specification:** the plugin needs a `specs/ext-btrfs.md` and a line in SPEC.md's index. Neither is the agent's to add, so the pull request proposes the text and asks the maintainer to place it, as with `ext-zfs`.
- **Code shared with `ext-zfs`** (restore staging, versions comparison) is copied, not shared, for now, so neither plugin depends on the other.
