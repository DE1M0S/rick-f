# Tasks

## 1. Platform write calls

- [x] 1.1 Add `create_snapshot`, `delete_snapshot` (with its `check` closure) and `rename_in_dir` to the subvolume trait with doc comments, as "unsupported" on macOS, Windows and in `Fake` unless scripted, and raise the API version only if change 1 has already shipped. Verify with `cargo build --workspace` and `cargo doc --no-deps`.
- [x] 1.2 Linux: open paths with `openat2` and `RESOLVE_NO_SYMLINKS | RESOLVE_NO_MAGICLINKS`, and map `ENOSYS` to "unsupported kernel". Verify with unit tests on tmpfs that a symbolic link component is refused and a plain path opens (spec: Symbolic link swapped in).
- [x] 1.3 Linux: `SNAP_CREATE_V2` read-only, `SNAP_DESTROY_V2` by name after `check` on the opened parent, and `renameat2` with `RENAME_NOREPLACE`, each `unsafe` block with `// SAFETY:` and a size assertion for its struct. Verify with unit tests for the error mapping and the opt-in real test (spec: Snapshot as owner, Not permitted, Nested subvolume, Name taken).

## 2. Rules in `ext-btrfs`

- [x] 2.1 The name check and the managed rule (design Decision 2) as pure functions. Verify with unit tests for every refused name and for `.snapshots`, `timeshift-btrfs` and a hand-made snapshot.
- [x] 2.2 `ext_btrfs::helper`: argument parsing to the three forms, refusal with 64, and `run` doing the checks as root through the platform. Verify with unit tests for every accepted and refused form (spec: Plain subvolume refused, Unknown form), with the fake service.

## 3. Actions

- [x] 3.1 *Create snapshot* form and job, creating `.rick-snapshots` when missing, refreshing the cache at the end. Verify with unit tests for spec scenarios Default name, Invalid name and Not on Btrfs, or inside a snapshot.
- [x] 3.2 *Rename snapshot*. Verify with unit tests for spec scenarios Rename and Snapper snapshot.
- [x] 3.3 *Delete snapshot* with its confirmation and partial failure. Verify with unit tests for spec scenarios Delete two, Snapper snapshot and Not a snapshot, plus one refused deletion among two.
- [x] 3.4 Elevation follow-up as in `ext-zfs`: one question, then one helper call per refused step, with the message without a helper naming what was needed. Verify with unit tests for spec scenarios Snapshot of a root-owned subvolume and Declined, with a scripted `Elevate`.

## 4. Helper binary and packaging

- [x] 4.1 `crates/rick/src/bin/rick-btrfs.rs` over `ext_btrfs::helper::run`, with a cleared environment, `ext-btrfs` as a fixed dependency of `rick`, and the helper bundled by `xtask` beside `rick`. Verify with `cargo xtask bundle` and a test that the binary exits 64 for no arguments.
- [x] 4.2 `packaging/linux/org.openbreach.rick.btrfs.policy` (en, de) in the Linux archive, and the `include_str!` test that it names creating, renaming and deleting. Verify with that test and with `release.yml` listing the file (spec: Shipped).

## 5. Close-out

- [x] 5.1 Integration tests in `crates/tests/tests/btrfs.rs`: create, then rename, then delete through the app with the fake service, the snapshot appearing on and leaving the timeline. Verify with `cargo test -p tests btrfs`.
- [ ] 5.2 Opt-in real test on the user-owned test image: create, rename and delete as the user, then delete with `user_subvol_rm_allowed`; the helper through `pkexec` by hand, written down for the pull request. Verify it is skipped in a plain `cargo test --workspace`.
- [x] 5.3 Update the `ext-btrfs` README, the draft `specs/ext-btrfs.md` text, and the changelog under *Unreleased*. Verify that `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test --workspace`, `cargo deny check` and `cargo doc --no-deps` pass.
