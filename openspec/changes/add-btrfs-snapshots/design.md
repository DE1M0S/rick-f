# Design

## Context

The motivation is in proposal.md, the behaviour in `specs/btrfs-snapshots/spec.md`. It builds on the subvolume service of `add-btrfs-subvolume-probe`, which answers three questions without privileges: the subvolume of a path, the reachable subvolumes below a folder, and the mounted Btrfs file systems. `ext-zfs` is the pattern for everything a user sees. It has a read-only provider, a decorator for the Info section and the timeline, and an action group. Its review fixed two things this plugin must not repeat: no slow work on the app thread (the decorator's job fills a cache that the actions read), and a restore that stages its copy before touching the live item.

## Goals / Non-Goals

**Goals:**
- Same user-visible model as ZFS: Browse, Back to live, Versions, Restore, Info, Timeline.
- No privileges, no external program, no new dependency.
- Every probe in a job; the menu and the run read caches only.

**Non-Goals:**
- Changing anything on the file system except through *Restore* into live folders.
- Sharing code with `ext-zfs` now. That extraction comes as its own change, once both plugins work.
- Reading Snapper's or Timeshift's catalogues.

## Decisions

### 1. Snapshots are browsed as local folders, not through a provider path

A Btrfs snapshot is a real folder at a real path (`/home/.snapshots/2/snapshot`), unlike ZFS's hidden `.zfs/snapshot`, which the automounter fills. *Browse snapshots* navigates to that local path. Opening, previewing, *Open with…*, copying out and the breadcrumb all work unchanged. The kernel refuses writes to a read-only snapshot with `EROFS`, which the existing operations already report.

- *Alternative: a `btrfs:/<subvolume>/@<snapshot>/<path>` provider as in ZFS.* It gives the same read-only answers, but it duplicates the local provider for files that are already local. It also needs `Provider::local_path` again for opening files, and it hides where the snapshot really is. It was rejected.
- The trade-off is that the core still offers rename, trash and the new-item commands inside a snapshot, which then fail with the read-only error. ZFS shows the same behaviour for *Delete permanently*. Hiding them would need a capability check in `ops` for local paths, which is out of scope. The user-visible part is listed in the pull request under *Needs a decision*.

The `btrfs` provider therefore holds only what no folder holds: `/~versions/<live path>`, the versions of one file. Each version is a file entry named `<snapshot> — <file name>`. It reads through the provider, and `Provider::local_path` (API 21) gives its path inside the snapshot, so *Open*, *Open with…* and the editor work as for ZFS.

There is no snapshot list as in ZFS's `/<dataset>`. An entry there would have to open a folder of another provider (the local one), and the provider contract has no such redirect: a `Symlink` entry's target stays in its own provider. An older snapshot is reached through the time slider, which lists every snapshot of the subvolume and navigates to the local folder. *Browse snapshots* goes to the newest one. Adding a cross-provider redirect to the contract would be a change to a public trait for one list, so it was rejected.

### 2. What counts as a snapshot, and where it is looked for

A subvolume `T` is a snapshot of live subvolume `S` when `T.parent_uuid == S.uuid` and `T` is read-only. A writable subvolume with a parent uuid counts as live. After a Snapper rollback the mounted root is itself such a writable snapshot, and its own snapshots point at it.

The search covers the union of:
- the reachable subvolumes below `S`'s root folder (Snapper on `@home`: `/home/.snapshots`);
- the reachable subvolumes below each mount point of the same file system (Snapper on `@`: `/.snapshots`, when the folder asked about is in `@`).

Results are de-duplicated by subvolume id. A path is "inside a snapshot" when its subvolume is a snapshot by this rule, and its live counterpart is the mounted subvolume (or a subvolume reachable below a mount) whose uuid equals the snapshot's parent uuid. The live folder is that subvolume's root joined with the path relative to the snapshot's root.

Nested subvolumes are not part of a snapshot. Inside a snapshot they show as empty folders, which is Btrfs's own behaviour. A folder in a nested subvolume belongs to that subvolume and has its snapshots or none.

### 3. Caching and threads

The plugin keeps a per-file-system cache, keyed by `(fsid, subvol id)`, holding the snapshot list and the newest snapshot holding a given relative folder, as `ext-zfs`'s `Datasets` does after its review fix:
- The decorator's job fills it while a folder is shown: it identifies the folder's subvolume, lists the snapshots, and checks which hold the folder.
- The actions' `availability` and `run` read only the cache, and are disabled with "Reading snapshots…" until it is filled.
- Entries expire after 30 seconds and are dropped on refresh.

Identifying the subvolume of a path is one `fstatfs` and one ioctl, but it is still file-system I/O. It runs in the decorator's job as well, so the app thread never calls the subvolume service.

### 4. Names and labels

A snapshot is named by its path relative to the mount point it was reached through (`.snapshots/2/snapshot`), and dated by its `otime`. Reading Snapper's `info.xml` for a number and description would be friendlier. It is left out, because it is Snapper's own format and needs a parser.

### 5. Restore, versions and timeline copied from `ext-zfs`

`restore.rs` (staging copy, trash, rename into place), the versions comparison (size or modification time against the next newer copy) and the timeline assembly are copied from `ext-zfs` and adapted to local snapshot paths. A shared crate would be a new extension point between two plugins, and the user chose to extract it later, once both exist. Each copied module names its `ext-zfs` origin in a comment, so the extraction can find them.

### 6. Platforms

The manifest declares Linux only, like `ext-zfs`. The subvolume service answers "not Btrfs" elsewhere, so the code needs no `cfg`. The manifest keeps the Extensions screen honest.

### 7. Testing

- **Unit tests** against the fake platform's scripted subvolume service from change 1, with a temporary directory standing in for the snapshot folders. They cover finding snapshots (Snapper on `@home`, on `@`, a writable copy, an unreachable one), Browse and Back, versions, restore including the failed-copy case, the Info section and the timeline.
- **Integration tests** in `crates/tests/tests/btrfs.rs`, registered in `tests/main.rs`: the plugin inside the application with the fake service. Browse, then Back, then restore a deleted file.
- **Opt-in real test** with `RICK_REQUIRE_BTRFS=1` and `RICK_BTRFS_TEST_DIR` on the test image from change 1, which carries a Snapper-style tree.

## Risks / Trade-offs

- [Listing below `/` on a system with hundreds of Snapper snapshots is slow] → it runs in a job, is cached per subvolume for 30 s, and `subvolumes_below` lists subvolumes, not files. It also stops when the job is cancelled.
- [Rename and trash offered inside a read-only snapshot fail late] → the error is the kernel's clear "Read-only file system". Hiding the commands is a later core change (Decision 1).
- [A hand-made read-only snapshot taken of a different subvolume than its parent uuid suggests (send/receive, `btrfs property set ro`)] → received snapshots have no parent uuid on the receiving side and are not shown. Properties changed afterwards are taken as they are.
- [Copied code drifts from `ext-zfs` before the extraction] → the origin comments. The extraction is the next change in this series once the four Btrfs changes land.
- [The live counterpart of a snapshot is not mounted (snapshot of a subvolume that is not mounted anywhere)] → *Back to live folder* is hidden, and *Restore* is hidden, because there is no live place to restore to.

## Migration Plan

Nothing to migrate. A new plugin, off until its file is in the plugins folder, as `ext-zfs`.

## Open Questions

- Whether Snapper's descriptions are worth a small parser later. That can be decided from use, and changes no requirement here.
