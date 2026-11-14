# Proposal

## Why

Fedora's and Ubuntu's installers use a flat Btrfs layout: `root`/`@` and `home`/`@home` sit side by side in the file system's top level (subvolume id 5), which is not mounted. Timeshift and btrbk keep their snapshots there too (`timeshift-btrfs/snapshots/…`, `/.btrbk_snapshots` or similar). Without root, nobody can reach them, so `add-btrfs-snapshots` cannot show them. Many desktop users rely on exactly these snapshots. Rick can reach them only if something with root mounts the top level, read-only, somewhere Rick can see it.

## What Changes

- A Btrfs action **Show all snapshots…** on a live folder on Btrfs. After one administrator prompt, it mounts that file system's top level read-only at a folder only the user can enter. From then on, the snapshots there are found like any reachable snapshot: in *Browse*, *Versions*, *Restore*, the Info section and the timeline.
- **Hide all snapshots** unmounts it again, with another prompt. Otherwise the mount stays until the next reboot, so later Rick sessions reuse it without a prompt.
- `rick-btrfs` (from `add-btrfs-snapshot-management`) gains two forms, `mount-top <fsid>` and `unmount-top <fsid>`. It takes no device or path from the caller.
- The top-level mount never shows up as a volume, and its live subvolumes (`@`, `@home` again) are never offered as places of their own.
- **Out of scope:**
  - writing to the top level: creating or deleting snapshots there, including Timeshift's;
  - reading Timeshift's or btrbk's catalogues;
  - mounting a Btrfs file system that is not already mounted somewhere;
  - a mount that survives a reboot, or one made at login;
  - a setting to make this automatic.

## Capabilities

### New Capabilities

- `btrfs-toplevel-mount`: mounting a mounted Btrfs file system's top level read-only for one user on request, so that snapshots outside every mounted subvolume can be browsed and restored from, and unmounting it again.

### Modified Capabilities

- `btrfs-snapshots`: snapshots below a top-level mount count as reachable, and the live subvolumes seen again inside it are not live folders.

## Impact

- **Crates touched:**
  - `ext-btrfs`: two actions, and the helper's two new forms in `ext_btrfs::helper`;
  - `platform`: nothing new for mounting (the helper runs the system's `mount` and `umount`, as `rick-zfs` runs `zfs`); the subvolume service from change 1 already lists the new mount;
  - `packaging/linux`: one more polkit action, `org.openbreach.rick.btrfs.mount`, kept apart from snapshot changes;
  - `tests`: integration and opt-in tests.
- **Dependencies:** none new. They still point downward.
- **Security:** this is the change with the real security question. A snapshot keeps the permissions its files had when it was taken. Mounting the top level therefore exposes, to the user who authenticated, every snapshot of every subvolume, including other users' homes and old files whose permissions were tightened later. The mount is read-only, `nosuid`, `nodev` and `noexec`, inside a folder of mode 0700 owned by the user. The design weighs this, and the pull request lists it under *Needs a decision*.
