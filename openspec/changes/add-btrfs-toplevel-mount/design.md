# Design

## Context

The motivation is in proposal.md, the behaviour in the two spec deltas. Three pieces from the earlier changes are already in place:
- `add-btrfs-subvolume-probe` lists every Btrfs mount the process sees, with its fsid and subvolume id, and lists reachable subvolumes below a folder.
- `add-btrfs-snapshots` searches for snapshots below every mount of the folder's file system.
- `add-btrfs-snapshot-management` brings `rick-btrfs`, its polkit action and the elevation flow.

A mount the helper makes in the system's mount namespace shows in Rick's `/proc/self/mounts`. Once the top level is mounted, the existing search finds what is below it, which leaves little new code. The weight of this change is in the security model.

`platform/src/linux/volumes.rs` already leaves out mounts under `/run` other than `/run/media` and `/run/mount`, so a mount under `/run/rick` never shows as a volume.

## Goals / Non-Goals

**Goals:**
- Timeshift and btrbk snapshots on a flat layout, with one prompt, readable by nobody but the user who asked.
- No new privileged program and no new dependency, only two more forms in `rick-btrfs`.

**Non-Goals:**
- Finer exposure than "the whole file system", such as mounting only the subvolumes that are snapshots of the user's own home. Mounting by subvolume id would do this, but it needs one mount per snapshot and one prompt or a long-lived root process. That may come later.
- A mount at login, or a permanent one in `fstab`.

## Decisions

### 1. Mount point `/run/rick/btrfs/<uid>/<fsid>`, folder `<uid>` mode 0700

The mounted file system's root replaces the mount point's own mode, so the protection must come from the parent folder. The helper creates:
- `/run/rick` (root, 0755);
- `/run/rick/btrfs` (root, 0755);
- `/run/rick/btrfs/<uid>` (owned by `<uid>`, 0700);
- the empty mount point `<fsid>`.

Each step uses `openat2` with `RESOLVE_NO_SYMLINKS` through the platform call from change 3. An existing folder with the wrong owner or mode is refused, not fixed. `/run` is a tmpfs, so everything is gone after a reboot, which is the lifetime the spec asks for.

- *Alternative: `$XDG_RUNTIME_DIR/rick-btrfs`.* Root would write into a folder the user controls, so the user could race a symbolic link into the path. `RESOLVE_NO_SYMLINKS` would stop that, but `/run/rick` keeps root's part of the path out of the user's hands entirely. Rejected.
- *Alternative: a private mount namespace for Rick.* Rick would have to start inside it, which needs root at start. Rejected.

### 2. The helper finds the device itself

`mount-top <fsid>` reads root's own `/proc/self/mounts` through the platform's Btrfs mount list. It picks the first mount with that fsid and uses its source device. A Btrfs file system across several devices mounts from any of its member devices. The caller supplies only the fsid, so it cannot make root mount an arbitrary device or image. The mount runs `/usr/bin/mount` (or `/bin/mount`) with `-t btrfs -o ro,nosuid,nodev,noexec,subvolid=5 <device> <mount point>`, a cleared environment and the C locale. `mount(2)` would need `unsafe` in `platform` for one call. `util-linux` is on every Linux system that has `pkexec`.

`unmount-top <fsid>` opens the mount point without following links. It confirms through the mount list that this exact path is a Btrfs mount of subvolume 5 with that fsid, then runs `/usr/bin/umount <mount point>`. It then removes the empty mount point.

### 3. Who is "the user"

`pkexec` sets `PKEXEC_UID` to the caller's uid, and the helper takes it from there. It refuses to mount when that variable is missing. A root shell running `rick-btrfs mount-top` by hand has no `PKEXEC_UID` and is refused. That case needs no support, because `mount` is right there for such a shell.

### 4. The exposure, and why it is tolerated

While the mount exists, the user can read, through `/run/rick/btrfs/<uid>/<fsid>`:
- every subvolume and snapshot of the file system, including other users' homes, subject to each file's mode at the time of the snapshot;
- files whose permissions were tightened after the snapshot, under the old permissions.

This is tolerated because:
- the user has just authenticated as administrator and could read all of this with `sudo` anyway;
- nobody else can enter the folder;
- the mount is read-only and cannot create devices or setuid programs;
- the explanation before the prompt says it in plain words.

The remaining case is a user who is not an administrator, whose administrator types the password for them, a family or kiosk setup. That user then sees old snapshots of other homes until the next reboot or *Hide all snapshots*. The polkit message names this, so the administrator knows what they approve. This is the first *Needs a decision* item. The options are as built, Stage B removed, or a narrower mount by subvolume id that needs a long-lived helper.

### 5. Live subvolumes inside the top-level mount

Inside the mount, `@` and `@home` appear a second time, read-only. Snapshot discovery (change 2) ignores every subvolume below a top-level mount that is not a snapshot by its rule. A path inside such a non-snapshot subvolume gets no Btrfs actions or timeline. Mapping a snapshot back to its live folder considers only mounts outside `/run/rick/btrfs`, so *Back to live folder* goes to `/home`, not to the read-only copy.

### 6. Finding the mount again

`ext-btrfs` recognises a top-level mount of its own as a Btrfs mount with subvolume id 5 at `/run/rick/btrfs/<own uid>/<fsid>`. A new Rick session therefore sees it with no prompt. The plugin's cache key includes the set of such mounts, so a mount or unmount drops cached snapshot lists. The platform's mount watch, already used for volumes, triggers a refresh when one appears or goes away.

### 7. A separate polkit action

`org.openbreach.rick.btrfs.mount` is separate from `org.openbreach.rick.btrfs`, because it exposes data rather than changing it, and an administrator may want to allow one and not the other. Both point at the same helper path. `pkexec` picks the action by matching the executable and arguments, and a policy can only distinguish by program, so the helper's `mount-top` form is reached through a second path. It is the same binary installed as a hard link `rick-btrfs-mount` beside `rick-btrfs`, and it refuses snapshot forms. The plain `rick-btrfs` refuses mount forms. That keeps one binary and two actions.

- *Alternative: one action for everything.* It is simpler, but the prompt's message could not say which risk the user approves. Rejected.

## Risks / Trade-offs

- [The exposure in Decision 4] → mode-0700 folder, read-only and `nosuid,nodev,noexec`, an explicit explanation, a separate polkit action, and gone at reboot. Listed under *Needs a decision*.
- [The mount outlives Rick and is forgotten] → the Info section shows "All snapshots shown (until restart)" with *Hide all snapshots* beside it.
- [Several devices, or a degraded file system] → the helper uses the device of an existing mount, which the kernel already accepted. A degraded file system then mounts read-only like any other.
- [Timeshift snapshots are writable copies taken from read-only ones during restore] → only read-only snapshots count (change 2's rule), so Timeshift's restore leftovers are ignored.
- [`mount` from util-linux behaves differently on some distributions] → only the plain `-t -o` form is used, the same on every util-linux since 2.x.

## Migration Plan

Nothing to migrate. Without a top-level mount, nothing changes from change 2.

## Open Questions

None that change the plan. The exposure question in Decision 4 is for the maintainer and goes into the pull request.
