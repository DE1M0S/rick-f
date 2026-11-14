# Spec Delta

## ADDED Requirements

### Requirement: Snapshots in a top-level mount
While the user has a top-level mount of a file system, the plugin SHALL also look for snapshots below that mount. They count as reachable, and the 30-second cache SHALL be dropped when such a mount appears or goes away. Subvolumes found there that are not snapshots SHALL be ignored.

#### Scenario: Snapshot only in the top level
- **WHEN** a snapshot of `@home` lies only in the unmounted top level, and the user has mounted the top level with *Show all snapshots…*
- **THEN** it is listed among the snapshots of a folder below `/home`

#### Scenario: Without the mount
- **WHEN** the same snapshot exists and no top-level mount exists
- **THEN** it is not listed, and nothing reports an error
