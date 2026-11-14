# Spec Delta

## ADDED Requirements

### Requirement: Create a read-only snapshot
The platform SHALL create a read-only snapshot of the subvolume whose root is a given folder. The snapshot is placed under a given name in a given folder on the same file system. The call SHALL resolve the source and the destination folder without following a symbolic link in any component, and SHALL check that the source is a subvolume root on the same opened folder it snapshots. It SHALL report the kernel's refusal (no permission, name taken, not a subvolume root, other file system) as distinct errors, and SHALL answer "unsupported" on macOS and Windows.

#### Scenario: Snapshot as owner
- **WHEN** the user owns the subvolume root `/data` and may write to `/data/.rick-snapshots`
- **THEN** the call creates the read-only snapshot `/data/.rick-snapshots/rick-1` of `/data`

#### Scenario: Not permitted
- **WHEN** the subvolume root `/home` is owned by root and the call runs as a user
- **THEN** it fails with a permission error and creates nothing

### Requirement: Delete a snapshot
The platform SHALL delete a snapshot given its path, resolving the path without following a symbolic link in any component, and SHALL hand the caller the facts of the subvolume it is about to delete (read-only, parent uuid, path) to check before the deletion on the same opened folder. It SHALL report a refusal for lack of permission, a subvolume with nested subvolumes, and a name that is no subvolume as distinct errors, and SHALL answer "unsupported" on macOS and Windows.

#### Scenario: Not permitted
- **WHEN** the file system is mounted without `user_subvol_rm_allowed` and the call runs as a user
- **THEN** it fails with a permission error and the snapshot stays

#### Scenario: Nested subvolume
- **WHEN** the snapshot holds a nested subvolume
- **THEN** it fails with that reason and nothing is deleted

### Requirement: Rename inside one folder
The platform SHALL rename an entry inside one folder without replacing an existing entry, resolving the folder without following a symbolic link in any component, and SHALL refuse a name with `/` or NUL.

#### Scenario: Name taken
- **WHEN** `before-upgrade` already exists in the folder and an entry is renamed to it
- **THEN** the rename fails with "name taken" and both entries stay
