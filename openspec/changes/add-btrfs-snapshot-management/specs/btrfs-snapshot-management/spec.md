# Spec Delta

## Purpose

Lets people take, rename and delete Btrfs snapshots from Rick, as the user where the kernel allows it and through a narrow privileged helper where it does not, without ever touching the snapshots Snapper or Timeshift manage.

## ADDED Requirements

### Requirement: Create snapshot
*Create snapshot* on a live folder on Btrfs SHALL open a form with a name, prefilled `rick-YYYY-MM-DD-HHMMSS` in local time. Confirming SHALL create one read-only snapshot of the folder's subvolume at `.rick-snapshots/<name>` in the subvolume's root folder, creating `.rick-snapshots` when it is missing. A name that is empty, contains `/` or a NUL, is `.` or `..`, or is longer than 255 bytes SHALL be marked in the form, and the form then cannot be confirmed. A name already taken SHALL fail the job and name it. The new snapshot SHALL appear in the folder's snapshots, the Info section and the timeline when the job ends.

#### Scenario: Default name
- **WHEN** the user creates a snapshot of `/home/ann/docs` at 14:03:07 on 2026-11-14 with the default name
- **THEN** `/home/.rick-snapshots/rick-2026-11-14-140307` is a read-only snapshot of `@home`, and the timeline gains its point

#### Scenario: Invalid name
- **WHEN** the user types `a/b` as the name
- **THEN** the form marks the name and cannot be confirmed

#### Scenario: Not on Btrfs, or inside a snapshot
- **WHEN** the folder is not on Btrfs or lies inside a snapshot
- **THEN** *Create snapshot* is not offered

### Requirement: Rename snapshot
*Rename snapshot* SHALL be offered on one snapshot inside a `.rick-snapshots` folder, shown at its root, with the same name check as *Create*. It SHALL rename the snapshot within that folder only.

#### Scenario: Rename
- **WHEN** the user renames `rick-2026-11-14-140307` to `before-upgrade`
- **THEN** `/home/.rick-snapshots/before-upgrade` is that snapshot, and the old name is gone

#### Scenario: Snapper snapshot
- **WHEN** the selection is `/home/.snapshots/12/snapshot`
- **THEN** *Rename snapshot* is not offered

### Requirement: Delete snapshot
*Delete snapshot* SHALL be offered on snapshot roots that are read-only snapshots, have a parent uuid, and are not managed by Snapper or Timeshift. Managed means the snapshot lies in a `.snapshots` subvolume or in a `timeshift-btrfs` folder. One confirmation SHALL name each snapshot by its path and say it cannot be undone. Then one job deletes them one by one. A snapshot the kernel refuses to delete (nested subvolume, busy) SHALL be reported with the kernel's reason and stay. The others are still deleted.

#### Scenario: Delete two
- **WHEN** the user selects two of Rick's snapshots and confirms
- **THEN** both are gone, and the timeline and Info section no longer list them

#### Scenario: Snapper snapshot
- **WHEN** the selection includes `/home/.snapshots/12/snapshot`
- **THEN** *Delete snapshot* is disabled with the reason that Snapper manages it

#### Scenario: Not a snapshot
- **WHEN** the selection is a writable subvolume or a plain folder
- **THEN** *Delete snapshot* is not offered

### Requirement: Elevation
Each change SHALL run as the user first. When the kernel refuses it for lack of permission, Rick SHALL ask once whether to run the refused steps as administrator. On yes, each SHALL run through the platform's elevation prompt as one call of the helper `rick-btrfs`. A dismissed prompt or a second refusal SHALL report "Permission denied" and change nothing more. Without the elevation prompt or the helper, the refusal SHALL be reported as it is, naming what would have been needed (ownership of the subvolume root, or the `user_subvol_rm_allowed` mount option).

#### Scenario: Snapshot of a root-owned subvolume
- **WHEN** the user creates a snapshot of `/home`, which root owns, and accepts the question and the prompt
- **THEN** the snapshot is created by `rick-btrfs`, and Rick itself never runs as root

#### Scenario: Declined
- **WHEN** the user declines the question
- **THEN** nothing is created, and the job reports "Permission denied"

### Requirement: The privileged helper
`rick-btrfs` SHALL accept exactly these forms and refuse every other with exit code 64, before touching the file system:
- `snapshot <subvolume root> <name>`: creates `<subvolume root>/.rick-snapshots/<name>` read-only;
- `rename <subvolume root> <old> <new>`: renames inside `<subvolume root>/.rick-snapshots`;
- `delete <path>`: deletes the snapshot at `<path>`.

It SHALL check as root, on the opened objects, every rule the actions check:
- the source is a subvolume root;
- `.rick-snapshots` is a real folder, not a link, and is created owned by root with mode 0755 when missing;
- a name passes the name check;
- a snapshot to delete is read-only, has a parent uuid, and is not managed by Snapper or Timeshift.

It SHALL resolve no path through a symbolic link. It SHALL run with a cleared environment and start no other program. It SHALL report a kernel refusal with the kernel's reason and a non-zero exit code.

#### Scenario: Plain subvolume refused
- **WHEN** `rick-btrfs delete /home` is run, `/home` being a writable subvolume without parent uuid
- **THEN** it exits 64 and `/home` is untouched

#### Scenario: Symbolic link swapped in
- **WHEN** `/home/.rick-snapshots` is a symbolic link to `/etc` and `rick-btrfs snapshot /home x` is run
- **THEN** it refuses, and nothing is created in `/etc`

#### Scenario: Unknown form
- **WHEN** `rick-btrfs` is run with `subvolume delete /` or any option
- **THEN** it exits 64 and changes nothing

### Requirement: Polkit action
The Linux archive SHALL ship the polkit action `org.openbreach.rick.btrfs`, which requires administrator authentication every time. Its message SHALL name creating, renaming and deleting Btrfs snapshots, in English and German.

#### Scenario: Shipped
- **WHEN** the Linux archive is built
- **THEN** it holds `share/polkit-1/actions/org.openbreach.rick.btrfs.policy` and the `rick-btrfs` binary beside `rick`
