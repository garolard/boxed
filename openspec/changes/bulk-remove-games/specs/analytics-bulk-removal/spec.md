## Purpose

Records a single bulk removal event per confirmed action so analytics can attribute the action without exploding into N per-game events.

## ADDED Requirements

### Requirement: One bulk_games_removed event per confirmed bulk removal
The system SHALL emit exactly one `bulk_games_removed` analytics event after a confirmed bulk removal completes. The event SHALL carry the number of games removed and the collection size after removal. The system SHALL NOT emit individual `game_removed` events for the same bulk action.

#### Scenario: Bulk removal fires one bulk event with count and post-size
- **WHEN** a confirmed bulk removal of N games completes
- **THEN** exactly one `bulk_games_removed` event is emitted with `count: N` and `collection_size_after` equal to the collection size after removal

#### Scenario: Bulk removal fires no per-game events
- **WHEN** a confirmed bulk removal of N games completes
- **THEN** no `game_removed` event is emitted for any of the N games

#### Scenario: Cancelled bulk removal fires no event
- **WHEN** the user cancels the bulk-remove confirmation dialog
- **THEN** no `bulk_games_removed` event is emitted

### Requirement: The bulk_games_removed event is robust to transient analytics failures
If the analytics call fails or the analytics transport is unavailable, the bulk removal MUST still complete successfully and the Shelf MUST still reflect the removal. The event SHALL be dropped, not retried inline, to keep the operation fast and non-blocking.

#### Scenario: Analytics failure does not block the removal
- **WHEN** a confirmed bulk removal completes and the analytics call throws or times out
- **THEN** the Shelf reflects the removal and no exception propagates to the caller
