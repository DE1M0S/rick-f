# Notes

## Test bed (task 1.1)

`~/Documents/code/rick-devshell/btrfs-testbed up` builds and mounts it without `sudo`; `down` takes it away. It prints `RICK_BTRFS_TEST_DIR`.

- A sparse 2 GB image in `~/.cache/rick-btrfs-test/test.img`, made by `mkfs.btrfs -r <tree> --subvol @ --subvol @home --subvol @home/.snapshots`, so every folder belongs to the user.
- `udisksctl loop-setup` and `udisksctl mount` mount it as the user, top level (id 5) at `/run/media/<user>/ricktest`.
- `@scratch` is a subvolume for the tests that take snapshots (change 3): without root they cannot delete one, so they stay off `@home`.
- As owner of `@home`, the user may take read-only snapshots: `@home/.snapshots/1/snapshot`, `@home/.snapshots/2/snapshot` (Snapper style), `@home/locked/hidden` (in a folder of mode 000, unreachable), and `timeshift-btrfs/snapshots/2026-11-01/@home` (top level).

Found on the way:
- `btrfs subvolume list` and even `subvolume show` need root (`TREE_SEARCH`), so `btrfs-progs` cannot check the tree as the user; the opt-in real test of this change is the check.
- Without root: no `set-default`, and udisks mounts a device once, so "two mounts of one file system" cannot be built here. Task 3.5 checks it on recorded mount lines and on the one real mount; the two-mount case runs by hand with `sudo mount -o subvol=@home`.
- `SNAP_CREATE` as the owner of the source works unprivileged (change 3 relies on it).
