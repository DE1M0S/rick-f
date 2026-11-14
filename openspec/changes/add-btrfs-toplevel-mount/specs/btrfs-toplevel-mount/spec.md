# Spec Delta

## Purpose

Lets a user on a flat Btrfs layout reach the snapshots kept in the unmounted top level (Timeshift, btrbk), by mounting that top level read-only for them alone on request, and unmounting it again.

## ADDED Requirements

### Requirement: Show all snapshots
*Show all snapshots…* SHALL be offered on a live folder on Btrfs when the folder's file system has no top-level mount of Rick's. It SHALL first say what it does: mount the whole file system read-only for this user, including other users' snapshots, which keep their old permissions. It then asks for administrator authentication once, through the platform's elevation prompt and `rick-btrfs mount-top`. The file system's top level (subvolume id 5) SHALL be mounted with `ro,nosuid,nodev,noexec` at `/run/rick/btrfs/<uid>/<fsid>`, where `/run/rick/btrfs/<uid>` is owned by the user and has mode 0700. When the job ends, the folder's snapshots SHALL be read again.

#### Scenario: Timeshift snapshots appear
- **WHEN** `/home` is `@home` in a flat layout, Timeshift keeps `timeshift-btrfs/snapshots/2026-11-01_10-00-00/@home` in the top level, and the user runs *Show all snapshots…* and authenticates
- **THEN** the folder's timeline and Info section include that snapshot, and *Browse snapshots* can open it

#### Scenario: Other users cannot enter
- **WHEN** the top level is mounted for user 1000
- **THEN** another local user cannot list `/run/rick/btrfs/1000`

#### Scenario: Declined
- **WHEN** the user declines the explanation or dismisses the prompt
- **THEN** nothing is mounted and nothing is reported as an error

#### Scenario: No elevation
- **WHEN** there is no elevation prompt or no `rick-btrfs`
- **THEN** *Show all snapshots…* is not offered

### Requirement: Hide all snapshots
*Hide all snapshots* SHALL be offered on a live folder whose file system has a top-level mount of the user's. After one administrator prompt through `rick-btrfs unmount-top`, it SHALL unmount it. A pane showing a folder inside the mount SHALL then go to that folder's live counterpart, or to the user's home folder.

#### Scenario: Hide
- **WHEN** the user runs *Hide all snapshots* and authenticates
- **THEN** `/run/rick/btrfs/<uid>/<fsid>` is no longer mounted, and the Timeshift snapshots leave the timeline

### Requirement: Lifetime
A top-level mount SHALL stay until it is hidden or the system restarts. A later Rick session of the same user SHALL find and use it without a prompt. Quitting Rick SHALL NOT unmount it and SHALL NOT prompt.

#### Scenario: Next session
- **WHEN** the user quits Rick and starts it again
- **THEN** the Timeshift snapshots are still listed, and no prompt appears

### Requirement: Helper forms
`rick-btrfs` SHALL accept `mount-top <fsid>` and `unmount-top <fsid>`, where `<fsid>` is 32 hexadecimal digits, and refuse anything else in these forms with exit code 64. It SHALL take the invoking user from `PKEXEC_UID` and refuse to run without it. For `mount-top`, it SHALL find the device from its own mount table, as a Btrfs file system already mounted with that fsid. It SHALL refuse when the fsid is mounted nowhere. It SHALL create the folders as specified, without following a symbolic link, and run the system's `mount` from `/usr/bin` or `/bin` with a cleared environment. For `unmount-top`, it SHALL unmount only `/run/rick/btrfs/<uid>/<fsid>`, and only when that is a Btrfs mount of subvolume id 5.

#### Scenario: Fsid not mounted
- **WHEN** `rick-btrfs mount-top` is given an fsid no mounted Btrfs has
- **THEN** it exits 64 and mounts nothing

#### Scenario: Unmount something else
- **WHEN** `/run/rick/btrfs/1000/<fsid>` was replaced by a symbolic link to `/home`
- **THEN** `unmount-top <fsid>` refuses and `/home` stays mounted

#### Scenario: Run without pkexec
- **WHEN** `rick-btrfs mount-top <fsid>` runs without `PKEXEC_UID`
- **THEN** it exits 64

### Requirement: Not a place of its own
The top-level mount SHALL NOT be listed among the volumes. Subvolumes inside it that are not snapshots SHALL NOT be treated as live folders. A snapshot reached through it SHALL map back to the live folder of its mounted parent subvolume.

#### Scenario: Live subvolume seen twice
- **WHEN** the top level is mounted and holds `@home`
- **THEN** `/run/rick/btrfs/<uid>/<fsid>/@home` is not offered as a live folder, its folders have no snapshots of their own, and *Back to live folder* from a Timeshift snapshot of `@home` goes to `/home`

### Requirement: Polkit action
The Linux archive SHALL ship the polkit action `org.openbreach.rick.btrfs.mount`, separate from the snapshot action, with administrator authentication every time. Its message SHALL say, in English and German, that all snapshots of the file system become readable.

#### Scenario: Shipped
- **WHEN** the Linux archive is built
- **THEN** it holds `share/polkit-1/actions/org.openbreach.rick.btrfs.mount.policy`
