# Tasks

## 1. Helper

- [ ] 1.1 Parse `mount-top <fsid>` and `unmount-top <fsid>` (32 hexadecimal digits), accepted only under the name `rick-btrfs-mount`, with the snapshot forms refused there and the mount forms refused under `rick-btrfs`, and `PKEXEC_UID` required. Verify with unit tests for every accepted and refused form (spec: Run without pkexec).
- [ ] 1.2 `mount-top`: find the device from the Btrfs mount list, create `/run/rick/btrfs/<uid>/<fsid>` with the owners and modes of design Decision 1 without following links and refusing a wrong owner or mode, and run `mount` with the fixed options and a cleared environment. Verify with unit tests on a scripted mount list and a temporary root standing in for `/run` (spec: Fsid not mounted).
- [ ] 1.3 `unmount-top`: confirm the exact path is a subvolume-5 Btrfs mount of that fsid, run `umount`, remove the empty mount point. Verify with unit tests (spec: Unmount something else).

## 2. Plugin

- [ ] 2.1 Recognise the user's own top-level mounts, and drop cached snapshot lists when one appears or goes away through the mount watch. Verify with unit tests on the fake service (spec: Next session).
- [ ] 2.2 Discovery: search below top-level mounts, ignore non-snapshot subvolumes there, and map back only through mounts outside `/run/rick/btrfs`. Verify with unit tests (spec: Snapshot only in the top level, Without the mount, Live subvolume seen twice).
- [ ] 2.3 *Show all snapshots…* with its explanation, the prompt, and a re-read at the end; *Hide all snapshots* with the pane moving out of the mount. Verify with unit tests with a scripted `Elevate` (spec: Timeshift snapshots appear, Declined, No elevation, Hide).
- [ ] 2.4 The Info section's "All snapshots shown (until restart)" line with *Hide all snapshots*. Verify with a unit test.

## 3. Packaging

- [ ] 3.1 `packaging/linux/org.openbreach.rick.btrfs.mount.policy` (en, de; the message names that all snapshots become readable), and the hard link `rick-btrfs-mount` in the bundle and the archive. Verify with an `include_str!` test of the message and `cargo xtask bundle` producing both names (spec: Shipped).

## 4. Close-out

- [ ] 4.1 Integration test in `crates/tests/tests/btrfs.rs`: with the fake service, a top-level mount appearing adds a snapshot to the timeline, and disappearing removes it. Verify with `cargo test -p tests btrfs`.
- [ ] 4.2 By hand on the test image from change 1 with a Timeshift-style flat layout: show all snapshots through `pkexec`, check `ls` as another user is refused (spec: Other users cannot enter), restore a file, hide. Write the steps and result into the pull request.
- [ ] 4.3 Update the `ext-btrfs` README, the draft `specs/ext-btrfs.md` text and the changelog under *Unreleased*. Verify that `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test --workspace`, `cargo deny check` and `cargo doc --no-deps` pass.
