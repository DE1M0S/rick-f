# Design

## Context

The motivation is in proposal.md, the behaviour in `specs/btrfs-subvolume-probe/spec.md`. A few constraints decide most of the shape:

- `unsafe` is allowed only in `platform`, and `cfg(target_os)` only there too. Plugins depend on `ext` and `types`. They reach the operating system only through the `Platform` object (`Registry::platform()`), the way `ext-zfs` reaches `Trash` and `Elevate`.
- `platform` already depends on `libc` and `rustix` on Linux, so ioctls need no new dependency.
- Fedora and Ubuntu put their subvolumes side by side in the unmounted top level (id 5) and mount only `@`/`root` and `@home`/`home`. An unprivileged process can only reach subvolumes below a folder it can open. This change answers what is reachable; `add-btrfs-toplevel-mount` deals with what is not.

## Goals / Non-Goals

**Goals:**
- One read-only platform trait with three questions: the subvolume of a path, the subvolumes below a folder, and the mounted Btrfs file systems.
- No privileges, no external program, no new crate.
- A scripted fake good enough for the plugin's tests.

**Non-Goals:**
- Any write ioctl (snapshot create or destroy, set read-only). Those come with `add-btrfs-snapshot-management`.
- Listing the whole file system as root (`TREE_SEARCH`). Stage B mounts the top level instead and then uses the same unprivileged listing.
- Sizes of subvolumes (qgroups). Quotas are off on most desktops, and reading them needs root.

## Decisions

### 1. A platform trait, not the `btrfs` command line or `libbtrfsutil`

A new trait `Subvolumes` in `platform/src/traits.rs`, joined into `Platform`, with a Linux implementation built on ioctls and "not Btrfs" answers on macOS and Windows.

- *Alternative: `btrfs` command line, as `ext-zfs` uses `zfs`.* `btrfs-progs` is not installed everywhere, and this machine has no copy. Its `subvolume list` has needed root for most of its history, and its output is meant for people, not for parsing. It was rejected because Stage A has to work without it.
- *Alternative: the `libbtrfsutil` C library through a sys crate.* That brings a new dependency with a C build, and the library is packaged separately from the kernel. We need only six ioctls. It was rejected as more dependency than it saves.

### 2. Which ioctls, and how the answers are put together

| Question | How |
|---|---|
| Btrfs at all? | `fstatfs`, `f_type == BTRFS_SUPER_MAGIC` |
| File system id | `BTRFS_IOC_FS_INFO` (`fsid`) on any fd on the file system |
| Subvolume of a path, and its facts | `BTRFS_IOC_GET_SUBVOL_INFO` on the path's fd: id, uuid, parent uuid, received uuid, otime, flags (read-only) |
| The subvolume's root folder | Walk up from the path while the parent is in the same subvolume (same `st_dev` and same `GET_SUBVOL_INFO` id); the root folder has inode 256 |
| Subvolumes below a folder | `BTRFS_IOC_GET_SUBVOL_ROOTREF` on the subvolume root lists its direct child subvolumes (paged, 255 per call); `BTRFS_IOC_INO_LOOKUP_USER` turns each child into a path below the parent and checks the user may traverse it; open each reachable child and recurse; keep those whose path lies below the folder asked for |
| Mounted Btrfs | Parse `/proc/self/mountinfo`: file-system type `btrfs`, the mount point, the `subvolid=` and `subvol=` options, the source device; file-system id from `FS_INFO` on the mount point |

The parsing of `/proc/self/mountinfo` is plain Rust in `platform/src/linux/`, including its octal escapes (`\040` for a space). The struct layouts mirror `linux/btrfs.h`, and a compile-time size assertion for each catches a mistake in the layout before it reaches the kernel.

### 3. Types

`BtrfsFsId` (16 bytes), `SubvolumeInfo { fs, id, uuid, parent_uuid: Option<_>, otime: SystemTime, read_only, root: PathBuf }`, `ListedSubvolume { info, path }` and `BtrfsMount { mount_point, fs, subvol_id, subvol_path, device }` live in `platform` and are re-exported through `ext::platform`, like `Volume`. The uuids are plain byte arrays. Formatting them belongs to the plugin.

### 4. Cancelling and limits

`subvolumes_below(path, stop: &dyn Fn() -> bool)` checks `stop` before each ioctl round. A cycle cannot happen, because subvolume trees are trees. As a guard against a broken file system, recursion stops at depth 64 and logs once at `warn`.

### 5. Unsupported kernels

The unprivileged ioctls arrived in 2018 (kernel 4.18). An older kernel answers `ENOTTY`. That is logged once at `debug`, and the call behaves as "not Btrfs" or "nothing listed", never as an error the user sees.

### 6. API version

The API version goes up by one, from 21 to 22. If `dev` takes 22 first, this change takes the next free number, as the time slider did.

### 7. Testing

- **Unit tests in `platform`:** parsing mountinfo, including escapes, `subvolid=` missing on old kernels, and other file systems; assembling a listing from scripted ioctl answers behind a small internal seam; the size assertions.
- **Fake:** `Fake` gets builder methods to script subvolumes, listings and mounts.
- **Opt-in real tests** (`RICK_REQUIRE_BTRFS=1`, `RICK_BTRFS_TEST_DIR=<a folder on Btrfs>`): identify a subvolume and a snapshot, list a Snapper-style tree, and check that an unreadable snapshot is skipped. Without the variables they print a skip note, as the ZFS real-pool test does. The tree is built by hand once. The tasks describe how, with `mkfs.btrfs` on an image file and `udisksctl` to mount it without `sudo`.

## Risks / Trade-offs

- [A struct layout differs from the kernel's] → compile-time size assertions, plus the opt-in real test on two kernels: this machine's 7.0 and the maintainer's Fedora.
- [`INO_LOOKUP_USER` refuses a child whose path the user cannot traverse, even if the snapshot itself is readable] → that is the intended behaviour: Rick shows what the user could open anyway.
- [ID-mapped mounts or user namespaces change what is reachable] → no special handling; the kernel's own permission checks decide.
- [A public trait change ripples into every `Platform` implementor] → there are three (Linux, macOS, Windows) plus `Fake`, all changed in this change; the API bump makes old plugins refuse to load instead of crashing.
- [`/proc/self/mountinfo` is missing (unusual containers)] → empty mount list, logged at `debug`.

## Migration Plan

Nothing to migrate. The trait is new, and existing plugins are rebuilt with the workspace.

## Open Questions

- Should CI tier 2 also run the real-Btrfs tests? GitHub's Linux runners have passwordless `sudo`, so a loop image could be built there. This can be decided after the change works locally, and it changes no requirement.
