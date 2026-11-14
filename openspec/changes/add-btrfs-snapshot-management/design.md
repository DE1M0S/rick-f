# Design

## Context

The motivation is in proposal.md, the behaviour in the two spec deltas. This change builds on `add-btrfs-subvolume-probe`, whose subvolume service gains the write calls, and on `add-btrfs-snapshots` for the plugin, its cache and its actions group. `ext-zfs` is the pattern for the user-facing flow:
- try as the user;
- on a permission refusal, ask once and run each refused command through `platform::Elevate` (`pkexec`) as one call of a narrow helper binary built from the plugin crate (`rick-zfs` from `ext_zfs::helper`, `crates/rick/src/bin/rick-zfs.rs`);
- ship a polkit policy in `packaging/linux`.

Btrfs differs in two ways:
- **Little delegation.** `SNAP_CREATE_V2` requires the caller to own the source subvolume's root (`inode_owner_or_capable`) and to have write access to the destination. `SNAP_DESTROY_V2` requires `CAP_SYS_ADMIN`, unless the file system is mounted with `user_subvol_rm_allowed` and the caller may write to the parent. On Fedora and Ubuntu, `/` and `/home` belong to root, so the helper is the normal path.
- **No command line to run.** `rick-zfs` runs the system's `zfs`. `btrfs-progs` may be missing, so `rick-btrfs` makes the ioctls itself through `platform`.

## Goals / Non-Goals

**Goals:**
- Create, rename and delete with one question and at most one prompt per step, as for ZFS.
- A helper whose whole behaviour fits in a page and can be reviewed alone.
- Never touch Snapper's or Timeshift's snapshots.

**Non-Goals:**
- One prompt for several steps (a batch form of the helper), the same as ZFS's review point 6.
- A snapshot location other than `.rick-snapshots` (no setting).
- Making subvolumes, or snapshots that are not read-only.

## Decisions

### 1. Where Rick's snapshots go: `<subvolume root>/.rick-snapshots/<name>`

This follows Snapper's own pattern (`/.snapshots` inside the subvolume), so the snapshot is reachable without root, and `add-btrfs-snapshots` finds it below the subvolume's root. It is nested, so it is not part of later snapshots of the same subvolume: nested subvolumes appear as empty folders in a snapshot. Its own folder keeps Rick out of Snapper's numbering and cleanup.

- *Alternative: beside the subvolume in the top level, as Timeshift does.* It is unreachable without mounting the top level (change 4), so it was rejected.
- *Alternative: let the user pick the folder.* That would be a setting the spec does not name, so it was rejected.

`.rick-snapshots` is created by whoever creates the first snapshot: the user when they own the subvolume root, otherwise the helper as root with mode 0755. The snapshots inside keep the permissions of their source's files, so the folder's mode leaks only names.

### 2. Which snapshots may be deleted

The rule is: read-only, has a parent uuid, and not managed. Managed means the path has a `.snapshots` component that is itself a subvolume (Snapper), or a `timeshift-btrfs` component. The actions check this from the cache. The helper checks it again as root, on the subvolume it opened, right before the ioctl.

Rename is narrower and covers only Rick's own snapshots in `.rick-snapshots`. A hand-made snapshot elsewhere may be in a path a script relies on, and Snapper's numbers carry meaning, so neither is renamed.

### 3. The write calls live in `platform`, path-based and free of symbolic links

The trait gains:
- `create_snapshot(source_root, dest_dir, name)`: read-only via `BTRFS_SUBVOL_RDONLY` in the `SNAP_CREATE_V2` flags;
- `delete_snapshot(path, check)`: `SNAP_DESTROY_V2`, by name in the opened parent.

Both open every path with `openat2` and `RESOLVE_NO_SYMLINKS | RESOLVE_NO_MAGICLINKS` (kernel 5.6+). The caller never handles a file descriptor, and no path is resolved twice. `delete_snapshot` takes a `check` closure. The platform opens the parent, reads the target's `GET_SUBVOL_INFO` through that parent, passes the facts to `check`, and deletes by name in the same opened parent only if `check` accepts. That way the helper's "is this a read-only, unmanaged snapshot" rule runs on the object it deletes, not on a path that could be swapped between check and delete.

- *Alternative: return file descriptors through the trait.* That would leak an OS handle type into a cross-platform public trait, so it was rejected.
- *Alternative: delete by subvolume id (`BTRFS_SUBVOL_SPEC_BY_ID`, kernel 5.7).* It is also free of races, but it needs an fd on the file system anyway, and the check would still have to read the info by id. The closure is simpler. This can be revisited if the closure proves awkward.

On kernels before 5.6, `openat2` answers `ENOSYS`. The write calls then fail with "unsupported kernel". Reading still works.

### 4. Rename is `renameat` with `RENAME_NOREPLACE`, not an ioctl

A subvolume is renamed like a folder, if the caller may write to the parent. Rename stays out of the trait. `ext-btrfs` uses the platform's ordinary rename for the user attempt, and the helper uses `renameat2` with `RENAME_NOREPLACE` inside the opened `.rick-snapshots`. The helper needs `rustix` for that, which `platform` exposes as a small `rename_in_dir` call so the helper adds no dependency.

### 5. The helper `rick-btrfs`

It is built like `rick-zfs`: `crates/rick/src/bin/rick-btrfs.rs` is a thin `main` over `ext_btrfs::helper::run(args) -> ExitCode`, and the argument check is a pure function with unit tests for every accepted and refused form. Exit codes are 0 for success, 64 for refused arguments, 69 for an unsupported kernel, and 1 for a kernel refusal with its reason on stderr. The environment is cleared on entry and the C locale set, and nothing else is started. It is found as `RICK_BTRFS_HELPER` or beside `rick`, like `rick-zfs`.

Threats considered:

| Threat | Answer |
|---|---|
| A symbolic link swapped in for `.rick-snapshots` or a path component | `RESOLVE_NO_SYMLINKS` on every open, so the helper refuses |
| A path swapped between check and delete | check and delete on the same opened parent (Decision 3) |
| Deleting a live subvolume or `/` | needs read-only plus a parent uuid, checked as root |
| Destroying Snapper's history | the managed rule, checked as root |
| A name with `/`, `..` or NUL escaping `.rick-snapshots` | the name check, plus the open relative to the opened folder |
| Snapshotting a subvolume to read someone else's files | the snapshot keeps every file's owner and mode, and the prompt already asked for administrator authentication |
| An option smuggled in | the helper takes no options |

### 6. Polkit and packaging

`packaging/linux/org.openbreach.rick.btrfs.policy` uses `auth_admin` for all three, `annotate key="org.freedesktop.policykit.exec.path"` set to `/opt/rick/current/rick-btrfs`, and English and German messages. Like `org.openbreach.rick.zfs`, it applies only when installed system-wide. Elsewhere, `pkexec` asks under its generic action. A unit test reads the policy with `include_str!` and checks that the messages name all three operations, as `ext-zfs` does.

### 7. Testing

- **`platform`:** unit tests for the `openat2` resolution (a symbolic link component is refused) on tmpfs; the ioctls through the opt-in real test only.
- **`ext-btrfs`:** the helper's argument check (every form, every refusal), the name check, the managed rule, and the actions against the fake service with scripted refusals. That covers the elevation question and prompt, a declined question, and the partial delete.
- **Opt-in real test** on the test image from change 1, owned by the user (`udisksctl` mounts it as the user). It creates, renames and deletes as the user, which works on an image the user owns. The `user_subvol_rm_allowed` case is covered by remounting the image with that option. The helper path runs by hand with `pkexec` and is noted in the pull request, as for ZFS.

## Risks / Trade-offs

- [A second privileged helper to review] → it is small, takes no options, starts no program, and its threats are listed above. Its tests cover every refusal.
- [`openat2` needs 5.6, Ubuntu 20.04 has 5.4] → that is past standard support. Writes fail with "unsupported kernel" there, and reading still works.
- [Snapper detection by folder name] → a hand-made `.snapshots` subvolume is treated as Snapper's, which errs on the side of not deleting.
- [`.rick-snapshots` takes space nobody cleans up] → snapshots are listed with their dates in the timeline and Info section, and *Delete snapshot* exists. Automatic cleanup would be a setting, so it is out.
- [`ext-btrfs` becomes a fixed dependency of `rick`, as `ext-zfs` did] → the same trade-off as ZFS's *Needs a decision* item 2, and the same recommendation.

## Migration Plan

Nothing to migrate. The helper and policy are new files in the archive.

## Open Questions

None that change the plan. The PR's *Needs a decision* holds:
- the snapshot folder name `.rick-snapshots`;
- the managed rule;
- the API bump, if this lands apart from change 1.
