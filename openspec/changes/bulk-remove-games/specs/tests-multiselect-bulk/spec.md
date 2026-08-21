## Purpose

Verifies the multiselect + bulk-remove behavior end to end, from the new repository and notifier methods up through the Shelf UI.

## ADDED Requirements

### Requirement: Repository bulk methods are covered by unit tests
Unit tests SHALL cover `CollectionRepository.removeMany` and `CollectionRepository.addMany`. The tests SHALL verify the empty-input no-op, the mixed present/absent id behavior of `removeMany`, and the overwrite-on-conflict behavior of `addMany`.

#### Scenario: removeMany empty input
- **WHEN** the repository's bulk delete is called with an empty id list
- **THEN** the test asserts the call completes and the collection is unchanged

#### Scenario: removeMany mixes present and absent ids
- **WHEN** the repository's bulk delete is called with a list that mixes present and absent ids
- **THEN** the test asserts the present ids are removed and no error is raised for the absent ids

#### Scenario: addMany overwrites an existing entry
- **WHEN** the repository's bulk insert is called with an entry whose id already exists
- **THEN** the test asserts the resulting row carries the supplied entry's owned-platform and `addedAt`

### Requirement: Notifier bulk methods are covered by tests using a fake repository
Tests SHALL cover `CollectionNotifier.removeMany` and `restoreMany`. The tests SHALL assert that `removeMany` snapshots the affected `Game` objects before delegating, fires one `bulk_games_removed` analytics event with the correct count and post-size, and updates the state via `_load`. The tests SHALL assert that `restoreMany` re-adds the supplied entries and fires no analytics event.

#### Scenario: removeMany snapshots before deleting
- **WHEN** the notifier's bulk remove is called with a list of ids
- **THEN** the test asserts the fake repository's bulk delete received the same ids and the returned snapshot contains the matching `Game` objects

#### Scenario: removeMany fires one bulk analytics event
- **WHEN** the notifier's bulk remove completes
- **THEN** the test asserts exactly one `bulk_games_removed` event was fired with the correct count and `collection_size_after`

#### Scenario: restoreMany fires no analytics event
- **WHEN** the notifier's bulk restore is called
- **THEN** the test asserts no analytics event is fired

### Requirement: GameCoverCard selection visuals are covered by widget tests
Widget tests SHALL cover `GameCoverCard` rendering in selectable mode. The tests SHALL verify that an unselected cover renders an empty selection badge and no accent border, and that a selected cover renders a filled checkmark badge and an accent border.

#### Scenario: Unselected cover in selectable mode
- **WHEN** a `GameCoverCard` is rendered with `selectable: true` and `selected: false`
- **THEN** the test asserts the empty selection badge is present and the accent border is absent

#### Scenario: Selected cover in selectable mode
- **WHEN** a `GameCoverCard` is rendered with `selectable: true` and `selected: true`
- **THEN** the test asserts the filled checkmark badge is present and the accent border is present

### Requirement: The end-to-end Shelf flow is covered by a widget test
An end-to-end widget test SHALL drive the Shelf from selection entry through confirmation, removal, and undo. The test SHALL override the `collectionProvider` (and any other providers required for the screen to render), enter selection mode, select multiple covers, confirm the dialog, and tap Undo on the resulting snackbar. The test SHALL assert that all selected games return to the Shelf in their prior state.

#### Scenario: Full bulk-remove + undo flow round-trips the Shelf
- **WHEN** the widget test enters selection mode, selects N games, confirms the dialog, and taps Undo
- **THEN** the test asserts that all N games are present in the Shelf state after the undo
