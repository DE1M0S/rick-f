# Tasks

## 1. Crate

- [x] 1.1 Create `crates/ext-btrfs` (manifest Linux only, API version from `add-btrfs-subvolume-probe`, `description`, README naming `ext` and `types` as its only dependencies), add the `btrfs` feature to `rick`, and add it to `xtask` bundling and `check-plugins.sh`. Verify with `cargo build --workspace`, `cargo deny check` and `rick --list-plugins` listing it.

## 2. Finding snapshots

- [x] 2.1 Snapshot discovery (design Decision 2): the subvolume of a folder, the union of reachable subvolumes below its root and below each mount of the same file system, kept when read-only with the folder's subvolume uuid as parent uuid, de-duplicated by id, newest first. Verify with unit tests on the fake service (spec scenarios: Snapper on the home subvolume, Snapshot of the root subvolume mounted elsewhere, Writable copy, Snapshot out of reach, Not Btrfs).
- [x] 2.2 The cache (design Decision 3): keyed by `(fsid, subvol id)`, the snapshot list and the newest snapshot holding a relative folder, 30 s expiry, dropped on refresh. Verify with unit tests for expiry and refresh.
- [x] 2.3 Map a path inside a snapshot to its live counterpart (by parent uuid, then the live root joined with the relative path), and a live path to the same folder in a snapshot. Verify with unit tests, including a snapshot whose live subvolume is not mounted.

## 3. Decorator

- [x] 3.1 Decorator job: while a folder is shown, identify its subvolume, read its snapshots and the newest holding the folder into the cache. Verify with a unit test that the app thread makes no call to the subvolume service.
- [x] 3.2 Info section *Btrfs* (spec: Info section), with *Loading…* until read. Verify with unit tests for a live folder and for a folder inside a snapshot.
- [x] 3.3 Timeline from the cache (spec: Timeline). Verify with a unit test of the points' order, labels and targets, and that a subvolume without snapshots offers none.

## 4. Actions and the versions location

- [x] 4.1 *Browse snapshots* and *Back to live folder*, reading only the cache. Verify with unit tests for spec scenarios Browse and back and Folder gone live, plus the "reading snapshots" state.
- [x] 4.2 The read-only `btrfs` provider with `/~versions/<live path>` and `local_path` for its entries, copying the comparison from `ext-zfs` with an origin comment. Verify with unit tests for spec scenarios Unchanged copies are left out and Deleted file, and that every write is refused as read-only.
- [x] 4.3 *Versions* action. Verify with a unit test that it is enabled for one live file and one file in a snapshot and disabled for a folder.
- [x] 4.4 *Restore*, copying the staging restore from `ext-zfs` with an origin comment. Verify with unit tests for spec scenarios Deleted file comes back, Live file replaced, Copy fails halfway and Declined, and that it is hidden without a trash.

## 5. Close-out

- [x] 5.1 Integration tests in `crates/tests/tests/btrfs.rs`, registered in `tests/main.rs`: inside the application with the fake service, browse, go back, restore a deleted file, open a version. The rename refused inside a read-only snapshot (spec: Read-only inside) needs the kernel and is checked in 5.2. Verify with `cargo test -p tests btrfs`.
- [x] 5.2 Opt-in real test on the test image of change 1 (`RICK_REQUIRE_BTRFS`, `RICK_BTRFS_TEST_DIR`): find the Snapper-style snapshots, browse, restore. Verify it is skipped in a plain `cargo test --workspace` and passes on the image.
- [x] 5.3 Draft `specs/ext-btrfs.md` text for the pull request (not committed to `specs/`), update the changelog under *Unreleased*, and confirm removing the plugin file leaves Rick working (spec: Removable). Verify that `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test --workspace`, `cargo deny check` and `cargo doc --no-deps` pass.
