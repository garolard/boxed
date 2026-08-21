## Purpose

Removes all selected games from the Shelf in a single confirmed action and lets the user undo the whole batch with one tap.

## ADDED Requirements

### Requirement: Bulk remove requires explicit confirmation
After the user taps Delete in the selection-mode app bar, the system SHALL present a confirmation dialog naming the number of games to be removed. The bulk removal SHALL NOT execute until the user confirms.

#### Scenario: Confirming removes the selected games
- **WHEN** the user taps Delete with N selected and then confirms the dialog
- **THEN** all N selected games are removed from the Shelf

#### Scenario: Cancelling leaves the selection intact
- **WHEN** the user taps Delete with N selected and then cancels the dialog
- **THEN** no games are removed and the selection still contains the same N games

### Requirement: Undo restores the entire batch removed in one action
After a confirmed bulk removal, the system SHALL show a single snackbar that offers Undo. Tapping Undo SHALL restore every game that was part of the bulk removal in the same Shelf state it was in before removal (same owned platform and same original `addedAt`). The undo window SHALL be bounded by the snackbar's lifetime, identical to single-game removal.

#### Scenario: Undo restores all removed games
- **WHEN** the user taps Undo on the snackbar shown after a bulk removal of N games
- **THEN** every one of the N games is restored to the Shelf in its prior owned-platform and `addedAt` state

#### Scenario: Undo is not available after the snackbar dismisses
- **WHEN** the snackbar shown after a bulk removal has been dismissed without tapping Undo
- **THEN** no undo action is available and the removal is permanent

#### Scenario: Bulk removal exits selection mode after confirming
- **WHEN** the user confirms the bulk-remove dialog
- **THEN** selection mode exits and the app bar returns to its normal layout once the dialog closes

### Requirement: Bulk removal is atomic from the user's perspective
While the bulk removal is in progress, the system SHALL NOT show an intermediate state where only some of the selected games are removed. Either all selected games disappear together, or none do.

#### Scenario: All selected games disappear together
- **WHEN** a confirmed bulk removal of N games completes
- **THEN** the Shelf no longer shows any of the N selected games

### Requirement: Bulk-remove undo never emits an analytics event
The undo path for a bulk removal SHALL NOT emit any analytics event, mirroring the single-game undo policy.

#### Scenario: Undo fires no analytics events
- **WHEN** the user taps Undo on the snackbar shown after a bulk removal
- **THEN** no analytics event is emitted for the undo
