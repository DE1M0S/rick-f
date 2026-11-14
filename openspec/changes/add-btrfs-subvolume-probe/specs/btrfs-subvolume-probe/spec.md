# Spec Delta

## Purpose

Lets Rick and its extensions learn, without privileges, which Btrfs subvolume a local path lies in, which subvolumes lie below a folder, and where Btrfs is mounted, so that snapshots can be found on any Btrfs layout.

## ADDED Requirements

### Requirement: Identify the subvolume of a path
For a local path on Linux, the platform SHALL report whether it lies on a Btrfs file system and, when it does, the file system's id and the subvolume it lies in: the subvolume's numeric id, its uuid, the uuid of the subvolume it was snapshotted from (none for a subvolume that is no snapshot), its creation time, whether it is read-only, and the folder that is its root. It SHALL need no privileges beyond read access to the path.

#### Scenario: Folder in a subvolume
- **WHEN** `/home` is the mounted subvolume `@home` and the platform is asked about `/home/ann/docs`
- **THEN** it reports Btrfs, the subvolume `@home` with its id and uuid, no parent uuid, and `/home` as the subvolume's root folder

#### Scenario: Snapshot
- **WHEN** `/home/.snapshots/1/snapshot` is a read-only snapshot of `@home` and the platform is asked about a folder inside it
- **THEN** it reports that snapshot's own id and uuid, `@home`'s uuid as its parent uuid, its creation time, and read-only

#### Scenario: Not Btrfs
- **WHEN** the platform is asked about a path on ext4, tmpfs or ZFS
- **THEN** it answers "not Btrfs", without an error

#### Scenario: Unreadable path
- **WHEN** the path does not exist or the user may not read it
- **THEN** the answer is an error that says so, and nothing panics

### Requirement: List the subvolumes below a folder
For a folder on Btrfs, the platform SHALL list the subvolumes that lie below it at any depth and that the user can reach, each with the same facts as for a single path and its path. Subvolumes the user cannot reach SHALL be left out without an error. The listing SHALL need no privileges and SHALL stop early when asked to.

#### Scenario: Snapper-style snapshots
- **WHEN** `/home` holds the nested subvolume `.snapshots` with snapshots `1/snapshot` and `2/snapshot` of `@home`, all readable by the user
- **THEN** listing below `/home` returns `.snapshots`, `.snapshots/1/snapshot` and `.snapshots/2/snapshot`, the last two with `@home`'s uuid as their parent uuid

#### Scenario: Unreachable subvolume
- **WHEN** one of the snapshots lies inside a folder the user may not enter
- **THEN** that snapshot is left out and the others are listed

#### Scenario: Not Btrfs
- **WHEN** the folder is not on Btrfs
- **THEN** the listing is empty, without an error

#### Scenario: Cancelled
- **WHEN** the caller cancels a listing of a folder with many subvolumes
- **THEN** the listing ends without visiting the rest

### Requirement: List the mounted Btrfs file systems
The platform SHALL list the mounted Btrfs file systems as the current process sees them: for each mount its mount point, the file system's id, the id and path of the mounted subvolume, and the source device.

#### Scenario: Flat layout
- **WHEN** one Btrfs file system is mounted twice, its subvolume `@` on `/` and `@home` on `/home`
- **THEN** both mounts are listed with the same file-system id and their own subvolume ids and paths

#### Scenario: No Btrfs mounted
- **WHEN** no Btrfs file system is mounted
- **THEN** the list is empty

### Requirement: Read only, everywhere safe
Identifying a subvolume and listing subvolumes or mounts SHALL never change a file system. On macOS and Windows it SHALL answer "not Btrfs" for every path and an empty list for every listing, without an error.

#### Scenario: Windows
- **WHEN** an extension asks the platform about `C:\Users\ann` on Windows
- **THEN** the answer is "not Btrfs"

### Requirement: Testable without Btrfs
The fake platform SHALL offer a scripted subvolume service that returns the subvolumes, listings and mounts a test sets up, so extensions can be tested on machines without Btrfs.

#### Scenario: Scripted snapshot
- **WHEN** a test scripts a subvolume and one snapshot of it and asks the fake about a path inside the snapshot
- **THEN** the fake reports the scripted snapshot with the scripted parent uuid
