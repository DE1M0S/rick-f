# Spec Delta

## Purpose

Lets people on Btrfs see the snapshots of the folder they are in, compare a file's versions across them and put a file back, without a shell, without root and without Snapper, as `ext-zfs` does for ZFS.

## ADDED Requirements

### Requirement: Find the snapshots of a folder
For a local folder on Btrfs, the plugin SHALL find the snapshots of the subvolume the folder lies in. A snapshot is a read-only subvolume whose parent uuid is that subvolume's uuid. The plugin looks for it below the subvolume's own root folder and below every mount point of the same file system, and SHALL include only snapshots the user can reach. It SHALL do this without privileges and never on the application's thread. Snapshots of one subvolume SHALL be cached for 30 seconds and read again after a refresh.

#### Scenario: Snapper on the home subvolume
- **WHEN** `/home` is the subvolume `@home` and `/home/.snapshots/1/snapshot` and `/home/.snapshots/2/snapshot` are read-only snapshots of it
- **THEN** a folder below `/home` has these two snapshots, the newer one first

#### Scenario: Snapshot of the root subvolume mounted elsewhere
- **WHEN** `/` is `@`, `/home` is `@home` on the same file system, and `/.snapshots/5/snapshot` is a snapshot of `@`
- **THEN** a folder below `/etc` has that snapshot, and a folder below `/home` does not

#### Scenario: Writable copy
- **WHEN** a writable subvolume has `@home`'s uuid as its parent uuid
- **THEN** it is not counted as a snapshot of `@home`, and folders in it are live folders with their own snapshots

#### Scenario: Snapshot out of reach
- **WHEN** a snapshot of `@home` lies only in the unmounted top level of the file system
- **THEN** it is not listed, and nothing reports an error

#### Scenario: Not Btrfs
- **WHEN** the folder is on another file system, or the platform is not Linux
- **THEN** the plugin shows no action, no Info section and no timeline, and reports nothing

### Requirement: Browse a snapshot as a folder
*Browse snapshots* on a live folder SHALL navigate the pane to the same relative folder inside the newest snapshot that holds it, as a local folder. When no snapshot holds the folder, the action SHALL be disabled with that reason. Until the snapshots have been read, the action SHALL be disabled with the reason that they are being read. *Back to live folder* inside a snapshot SHALL navigate to the corresponding live folder, or to its nearest existing parent.

#### Scenario: Browse and back
- **WHEN** the pane shows `/home/ann/docs` and both snapshots hold `ann/docs`
- **THEN** *Browse snapshots* shows `/home/.snapshots/2/snapshot/ann/docs`, and *Back to live folder* there shows `/home/ann/docs`

#### Scenario: Folder gone live
- **WHEN** the pane shows `ann/old` inside a snapshot and `/home/ann/old` no longer exists
- **THEN** *Back to live folder* shows `/home/ann`

#### Scenario: Read-only inside
- **WHEN** the user renames, trashes or creates an item inside a read-only snapshot
- **THEN** the operation fails with the file system's read-only error and the snapshot is unchanged

### Requirement: Versions of a file
*Versions* on one live file, or on one file inside a snapshot, SHALL navigate the pane to a read-only `btrfs` location that lists newest first each snapshot whose copy of the file differs in size or modification time from the next newer one listed. Each entry SHALL be named after its snapshot, and SHALL preview, open and copy like a file. The location SHALL refuse every change with "snapshots are read-only". A file deleted live SHALL still have its versions.

#### Scenario: Unchanged copies are left out
- **WHEN** `report.txt` is the same in snapshots 1 and 2 and different live
- **THEN** *Versions* lists one entry, snapshot 2's copy

#### Scenario: Deleted file
- **WHEN** `ann/gone.txt` exists only in snapshot 1
- **THEN** *Versions* on it inside snapshot 1 lists snapshot 1's copy

### Requirement: Restore from a snapshot
*Restore* on items inside a snapshot, or in a versions view, SHALL ask once. The question names the snapshot, the live paths the items go to and, apart, the live items that will be replaced. Then one job:
- creates missing parent folders;
- copies each item with its permissions and modification times, folders and symbolic links included, to a hidden name beside its live place;
- only when that copy is complete, moves the live item in the way to the trash and puts the copy in its place.

A copy that fails or is cancelled SHALL be removed and leave the live item as it was. An item whose live version cannot be trashed SHALL be skipped and reported. Without the host's trash, *Restore* SHALL be hidden.

#### Scenario: Deleted file comes back
- **WHEN** the user restores `ann/gone.txt` from snapshot 1 and confirms
- **THEN** `/home/ann/gone.txt` exists with snapshot 1's content and modification time

#### Scenario: Live file replaced
- **WHEN** the user restores `report.txt` over a live copy and confirms
- **THEN** the live copy is in the trash and the snapshot's copy is in its place

#### Scenario: Copy fails halfway
- **WHEN** a folder restore cannot read one of the snapshot's files
- **THEN** the live folder is unchanged, no hidden copy is left, and the error names the file

#### Scenario: Declined
- **WHEN** the user declines the question
- **THEN** nothing changes

### Requirement: Info section
The Info panel SHALL show a *Btrfs* section for a local entry on Btrfs with:
- the subvolume's root folder, its id, and whether it is read-only (its path inside the file system needs root to read, so it is not shown);
- for a snapshot, the subvolume it was taken of and its creation time;
- for a live subvolume, the number of snapshots found and the newest one's name and date, with *Loading…* until they are read.

Values SHALL copy as plain text.

#### Scenario: Live folder
- **WHEN** the selection is `/home/ann/docs`
- **THEN** the section names `/home`, the root folder of `@home`, its id, writable, 2 snapshots and the newest one

#### Scenario: Inside a snapshot
- **WHEN** the selection is inside `/home/.snapshots/1/snapshot`
- **THEN** the section says read-only, taken of `@home`, and the creation time

### Requirement: Timeline
The plugin SHALL offer the time slider a timeline for a live folder and for a folder inside one of its snapshots. The timeline has one point per snapshot of the subvolume, oldest first, at the snapshot's creation time. Each point is labelled with the snapshot's path relative to its mount, has the source *Btrfs*, and points at the same relative folder inside that snapshot, with the live folder as *Now*. It SHALL answer from the cached snapshot list. A subvolume without snapshots offers no timeline.

#### Scenario: Timeline of a folder
- **WHEN** the bar is shown on `/home/ann/docs`
- **THEN** it has two points, pointing at `ann/docs` inside snapshots 1 and 2

### Requirement: Removable
Removing the plugin file SHALL leave Rick fully working, and the plugin SHALL be listed as not supported and not loaded on macOS and Windows.

#### Scenario: Plugin removed
- **WHEN** `ext-btrfs` is not in the plugins folder
- **THEN** Rick starts and works, without Btrfs actions or Info section
