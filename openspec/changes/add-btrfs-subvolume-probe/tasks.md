# Tasks

## 1. Test bed

- [x] 1.1 Add `btrfs-progs` to the local dev shell (`~/Documents/code/rick-devshell`, not the repository) and a script `btrfs-testbed` there that builds the test tree without `sudo` (notes.md): a sparse 2 GB image, `mkfs.btrfs --subvol`, `udisksctl loop-setup`/`mount`, subvolumes `@`/`@home`, Snapper-style `@home/.snapshots/N/snapshot`, one snapshot in a folder of mode 000, one in the top level. Verify by building the tree from scratch on this machine and reading a file from each snapshot (`btrfs subvolume list` needs root, see notes).

## 2. Trait and types

- [x] 2.1 Add the `Subvolumes` trait and its types (`BtrfsFsId`, `SubvolumeInfo`, `ListedSubvolume`, `BtrfsMount`) to `platform/src/traits.rs` with doc comments. Join the trait into `Platform` and implement "not Btrfs" for macOS and Windows. Re-export everything through `ext::platform` and raise the API version (design Decision 6). Verify with `cargo build --workspace` and `cargo doc --no-deps`.
- [x] 2.2 Script the service in `Fake` (builder methods for subvolumes, listings and mounts). Verify with a unit test (spec: Testable without Btrfs, Scripted snapshot).

## 3. Linux implementation

- [x] 3.1 Parse `/proc/self/mountinfo` for Btrfs mounts with the parser of `linux/volumes.rs`, widened as needed, including octal escapes, `subvolid=`/`subvol=`, a missing `subvolid=` and other file systems. Verify with unit tests on recorded lines (spec: List the mounted Btrfs file systems).
- [x] 3.2 Add the ioctl definitions with compile-time size assertions and `// SAFETY:` comments, plus `fstatfs` detection and `FS_INFO`. Verify with unit tests that a tmpfs path answers "not Btrfs" (spec: Not Btrfs) and that the layout assertions compile.
- [x] 3.3 Identify the subvolume of a path: `GET_SUBVOL_INFO`, and the walk up to the root folder. Map `ENOTTY` to "not Btrfs" with one `debug` log, and `ENOENT`/`EACCES` to errors. Verify with unit tests through the internal seam and the opt-in real test for a subvolume and a snapshot (spec: Identify the subvolume of a path).
- [x] 3.4 List the subvolumes below a folder with `GET_SUBVOL_ROOTREF` paging, `INO_LOOKUP_USER`, recursion, the depth guard and `stop`. Verify with unit tests for paging, skipping, depth and cancelling, and the opt-in real test on the Snapper-style tree, including the skipped unreachable snapshot (spec: List the subvolumes below a folder).
- [x] 3.5 Fill in the fs id and subvolume path of each mount from task 3.1. Verify with unit tests on recorded lines of two mounts of one file system (spec: Flat layout) and with the opt-in real test that the test image's mount carries the fs id `FS_INFO` reports for a path in it.

## 4. Close-out

- [x] 4.1 Add the opt-in real test module in `crates/tests` (`RICK_REQUIRE_BTRFS`, `RICK_BTRFS_TEST_DIR`, a skip note otherwise) and register it in `tests/main.rs`. Verify it is skipped in a plain `cargo test --workspace` and passes on the test tree.
- [x] 4.2 Update the README of `platform` (the new service) and the changelog under *Unreleased*. Verify that `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test --workspace`, `cargo deny check` and `cargo doc --no-deps` all pass.
