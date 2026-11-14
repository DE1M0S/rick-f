# Proposal

## Why

With `add-btrfs-snapshots`, Rick shows a Btrfs subvolume's snapshots, but taking one before a risky change, or removing old ones, still needs a shell and `btrfs subvolume snapshot` or `delete` as root. `ext-zfs` offers *Create*, *Rename* and *Destroy snapshot* with a privileged helper for what the user may not do alone. Btrfs needs the same, with one difference: unlike `zfs allow`, Btrfs has almost no delegation. Snapshotting a subvolume needs ownership of its root folder, and deleting one needs root unless the file system is mounted with `user_subvol_rm_allowed`. So the helper is the normal path on a desktop, not the exception.

## What Changes

- Actions in the "Btrfs" group:
  - **Create snapshot** — on a live folder: a read-only snapshot of its subvolume, placed in `.rick-snapshots/<name>` at the subvolume's root, with a default name `rick-YYYY-MM-DD-HHMMSS`;
  - **Rename snapshot** — on one snapshot Rick made (inside `.rick-snapshots`);
  - **Delete snapshot** — on read-only snapshots that Snapper or Timeshift do not manage, with one confirmation naming each.
- Each runs as the user first. When the kernel refuses for lack of permission, Rick asks once and runs the refused step through a new privileged helper, **`rick-btrfs`**, via `pkexec`, as `ext-zfs` does with `rick-zfs`.
- `rick-btrfs` accepts exactly three forms (snapshot into `.rick-snapshots`, rename within `.rick-snapshots`, delete a read-only snapshot). It refuses everything else, works on file descriptors so a symbolic link swapped in cannot redirect it, and re-checks every rule as root.
- A polkit action `org.openbreach.rick.btrfs`, shipped like `org.openbreach.rick.zfs`.
- The platform's subvolume service gains two write calls, snapshot and delete, because they are ioctls and need `unsafe`.
- **Out of scope:**
  - writable snapshots, rollback, and setting or clearing the read-only flag;
  - deleting a plain subvolume, or a snapshot with nested subvolumes inside;
  - Snapper and Timeshift snapshots: Rick neither creates nor deletes in their folders, so their cleanup rules and catalogues stay right;
  - snapshots in the unmounted top level (`add-btrfs-toplevel-mount` mounts it read-only only);
  - quotas, and recursive snapshots of nested subvolumes.

## Capabilities

### New Capabilities

- `btrfs-snapshot-management`: creating, renaming and deleting Btrfs snapshots from Rick, with a narrow privileged helper for the steps the kernel refuses to a user.

### Modified Capabilities

- `btrfs-subvolume-probe`: the subvolume service is no longer read-only. It gains snapshot creation and snapshot deletion.

## Impact

- **Crates touched:**
  - `platform`: two methods on the subvolume trait, implemented with `BTRFS_IOC_SNAP_CREATE_V2` and `BTRFS_IOC_SNAP_DESTROY_V2` on Linux, "unsupported" elsewhere, scripted in `Fake`;
  - `ext`: no new API version if this lands in the same pull request as `add-btrfs-subvolume-probe`, otherwise one more;
  - `ext-btrfs`: the actions and the helper's argument check (`ext_btrfs::helper`);
  - `rick`: the `rick-btrfs` binary, built as `rick-zfs` is, which makes `ext-btrfs` a fixed dependency of `rick`;
  - `xtask`, `packaging/linux`: bundle the helper and the polkit policy;
  - `tests`: integration tests.
- **Dependencies:** none new. Dependencies still point downward: `rick` → `ext-btrfs` → `ext` → `platform`.
- **Security:** a new program run as root. Its argument rules are in the spec and its threats in the design. It touches only subvolumes, never plain files, and never follows a symbolic link.
- **Public trait change:** the subvolume trait gains two methods, implemented by every platform and the fake in this change.
