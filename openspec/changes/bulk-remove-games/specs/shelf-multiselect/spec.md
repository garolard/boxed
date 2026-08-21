## Purpose

Lets the user mark several covers on the Shelf and act on them together, replacing per-cover navigation with in-place selection.

## ADDED Requirements

### Requirement: Selection-mode entry is a visible app-bar action
The Shelf app bar SHALL expose a dedicated action that opens selection mode. Tapping it SHALL clear the existing selection and put the screen into selection mode. The action SHALL be visible without holding a modifier or performing a hidden gesture.

#### Scenario: User enters selection mode from the app bar
- **WHEN** the user taps the Shelf app bar's selection entry action while not in selection mode
- **THEN** the screen enters selection mode with an empty selection

#### Scenario: Existing selection is cleared on entry
- **WHEN** the user taps the selection entry action while a non-empty selection exists
- **THEN** the selection is cleared and selection mode is entered

### Requirement: Selection-mode app bar shows the selection count and exit/confirm actions
While the Shelf is in selection mode, the app bar title SHALL show the number of selected games, and SHALL expose a Close action that exits selection mode and a Delete action that begins the bulk-remove flow. The Delete action SHALL be disabled when no games are selected.

#### Scenario: Title reflects current selection size
- **WHEN** the Shelf is in selection mode and N games are selected
- **THEN** the app bar title displays "{N} selected"

#### Scenario: Close exits selection mode
- **WHEN** the user taps Close while in selection mode
- **THEN** the selection is cleared and the app bar returns to its normal layout

#### Scenario: Delete is disabled with no selection
- **WHEN** the Shelf is in selection mode with 0 games selected
- **THEN** the Delete action is disabled

### Requirement: Normal-mode overflow menu is hidden in selection mode
While the Shelf is in selection mode, the existing per-account overflow menu (Share / Export / Import) and any non-selection app-bar actions SHALL be hidden so the selection affordances occupy the full app bar.

#### Scenario: Overflow actions are hidden during selection mode
- **WHEN** the Shelf is in selection mode
- **THEN** the overflow menu and non-selection app-bar actions are not visible

### Requirement: Tapping a cover in selection mode toggles its selection
While the Shelf is in selection mode, tapping a cover SHALL add the corresponding game to the selection if absent, or remove it if present. Tapping a cover SHALL NOT navigate to that game's detail screen while selection mode is active.

#### Scenario: Tap selects an unselected cover
- **WHEN** the user taps a cover that is not currently selected while in selection mode
- **THEN** the cover becomes selected and the selection count increases by one

#### Scenario: Tap deselects a selected cover
- **WHEN** the user taps a cover that is currently selected while in selection mode
- **THEN** the cover becomes unselected and the selection count decreases by one

#### Scenario: Tap does not navigate to detail
- **WHEN** the user taps any cover while in selection mode
- **THEN** no detail screen is opened for that game

### Requirement: Selected covers show a selection badge and an accent border
While the Shelf is in selection mode, every cover SHALL render a selection badge in place of its owned indicator. A selected cover SHALL additionally show an accent-colored border. An unselected cover SHALL NOT show the border.

#### Scenario: Unselected cover shows an empty selection badge
- **WHEN** the Shelf is in selection mode and a cover is unselected
- **THEN** the cover renders an empty circular selection badge and no accent border

#### Scenario: Selected cover shows a filled selection badge and accent border
- **WHEN** the Shelf is in selection mode and a cover is selected
- **THEN** the cover renders a filled selection badge with a checkmark and an accent-colored border

### Requirement: Per-cover quick actions are hidden in selection mode
While the Shelf is in selection mode, the per-cover quick action button (Add / Remove) SHALL be hidden so the entire card area acts as a selection target.

#### Scenario: Per-cover quick action is not rendered in selection mode
- **WHEN** the Shelf is in selection mode
- **THEN** no cover displays its per-cover quick action button

### Requirement: Multiselect is scoped to the Shelf tab
Multiselect affordances SHALL appear only on the Shelf tab. Search, Recommendations, and Shared Collections SHALL NOT expose a selection entry action, selection-mode app bar, or selection badges.

#### Scenario: Other tabs do not show the selection entry action
- **WHEN** any tab other than the Shelf is active
- **THEN** no selection entry action is visible in that tab's app bar
