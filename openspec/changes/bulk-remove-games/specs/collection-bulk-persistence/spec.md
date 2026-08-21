## Purpose

Persists bulk remove and bulk restore operations on the collection so the Shelf reflects the user's intent after a restart.

## ADDED Requirements

### Requirement: removeMany deletes every requested id from the collection in one operation
The collection repository SHALL provide a bulk delete that removes all rows matching the given game ids in a single database operation. After it returns, no row matching any of the requested ids SHALL remain.

#### Scenario: removeMany deletes every requested id
- **WHEN** the repository's bulk delete is invoked with a list of ids that exist in the collection
- **THEN** every one of those rows is removed and no other rows are affected

#### Scenario: removeMany with empty input is a no-op
- **WHEN** the repository's bulk delete is invoked with an empty id list
- **THEN** no rows are deleted and the call completes successfully

#### Scenario: removeMany ignores ids that are not present
- **WHEN** the repository's bulk delete is invoked with a list of ids that mix present and absent ids
- **THEN** the present ids are removed and the absent ids are silently skipped without error

### Requirement: addMany re-inserts every supplied game entry in one operation
The collection repository SHALL provide a bulk insert that re-adds every supplied `Game` entry in a single database operation. Entries already present SHALL be overwritten with the supplied version (so that owned-platform and `addedAt` round-trip correctly on undo).

#### Scenario: addMany restores previously removed entries
- **WHEN** the repository's bulk insert is invoked with entries that were previously removed
- **THEN** those entries are present in the collection with the supplied owned-platform and `addedAt` values

#### Scenario: addMany overwrites conflicting entries
- **WHEN** the repository's bulk insert is invoked with an entry whose id already exists in the collection
- **THEN** the existing row is replaced with the supplied entry's data

### Requirement: Bulk persistence flips the recommendation cache as a single side effect
The first bulk remove or bulk restore performed after the collection changes SHALL cause the recommendations to be marked stale, so the next recommendation fetch rebuilds them. Subsequent bulk operations inside the same screen view SHALL NOT cause redundant recomputations beyond what the existing single-mutation path already triggers.

#### Scenario: A bulk remove marks recommendations stale
- **WHEN** a bulk remove completes
- **THEN** the next request for recommendations rebuilds the recommendation set rather than serving a cached one
