## Why

The Shelf currently removes one game at a time through `removeGameFlow` (`lib/widgets/remove_game_flow.dart:15`) — a confirmation dialog and an undo snackbar. Users pruning a collection they no longer own (a re-buy, a move, a clean-out) have to repeat that one-by-one flow for every title. The grid needs a visible way to select several covers and remove them in one confirmed action, with a single undo that restores the whole batch.

## What Changes

- Convert `_SummaryTab` (`lib/screens/home_screen.dart:242`) from `ConsumerWidget` to `ConsumerStatefulWidget` and hold the selection locally: a `Set<int> _selectedIds`. The Shelf tab is the only scope; Search, Recommendations, and Shared Collections are untouched.
- Add a visible `IconButton` (`Icons.checklist_rounded`, tooltip `menuSelectGames`) to the Shelf's `SliverAppBar` actions. It enters selection mode. In selection mode the app bar morphs: title becomes `"{N} selected"` (`nSelected`); actions become **Close** (exit selection, clears the set) and **Delete** (confirms bulk removal, disabled when 0 selected). The existing `PopupMenuButton` is hidden while selection mode is active.
- Extend `GameCoverCard` (`lib/widgets/game_cover_card.dart:16`) with three optional params — `bool selectable`, `bool selected`, `VoidCallback? onToggleSelection` — all default-preserving. When `selectable` is true: the `InkWell.onTap` toggles selection instead of pushing `GameDetailScreen`; the top-right `_OwnedPill` is replaced by a circular selection badge (empty ring when unselected, filled accent circle with checkmark when selected); the per-card `_QuickAddButton` is hidden to avoid tap collisions; an accent border (3 px, `AppColors.accent`) wraps the card when `selected`.
- Add bulk persistence: `CollectionRepository.removeMany(List<int>)` using a single `DELETE FROM collection WHERE id IN (?,?,...)`, and `addMany(List<Game>)` via a sqflite `Batch` insert with `ConflictAlgorithm.replace`.
- Add bulk state operations on `CollectionNotifier`: `removeMany(List<int>)` snapshots the affected `Game` objects (preserving `ownedPlatformId`, `ownedPlatformName`, `addedAt`), calls the repo, refreshes via `_load()`, and fires one analytics event; `restoreMany(List<Game>)` re-adds the batch and refreshes — no analytics, matching the single-`restore` policy.
- Add a `BulkGamesRemovedParams` typed analytics bundle and `AnalyticsService.logBulkGamesRemoved(...)` → a single `bulk_games_removed` event with `count` and `collection_size_after`. No per-game events for the bulk action.
- Bulk-remove UX: tap Delete → `AlertDialog` (`removeNGamesTitle` / `removeNGamesMessage`) → on confirm call `notifier.removeMany`, exit selection mode, show one `SnackBar` (5-second window, `persist: false`) `"N games removed"` (`gamesRemoved`) with **Undo** that calls `notifier.restoreMany` with the snapshot.
- Add localized strings to all four ARBs (`en`, `es`, `fr`, `pt`): `menuSelectGames`, `nSelected(int count)`, `removeNGamesTitle(int count)`, `removeNGamesMessage`, `gamesRemoved(int count)`. Run `flutter gen-l10n`; commit the generated `app_localizations*.dart` files.
- Add tests: `test/services/collection_repository_test.dart` for `removeMany`/`addMany`; `test/providers/collection_provider_test.dart` for the notifier bulk methods using a fake repo; `test/widgets/game_cover_card_test.dart` for the selection badge and border; `test/widgets/bulk_remove_flow_test.dart` for the end-to-end flow against `HomeScreen` (entry, multi-select, confirm, undo).

## Capabilities

### New Capabilities

- `shelf-multiselect`: Local selection state in `_SummaryTab` driven by a dedicated IconButton in the Shelf app bar; `GameCoverCard` gains an opt-in `selectable` mode that swaps the tap target, hides the per-card remove button, replaces the owned pill with a circular selection badge, and draws an accent border on selected cards.
- `bulk-remove-flow`: Confirmation dialog → `CollectionNotifier.removeMany` → single snackbar with **Undo** that calls `restoreMany` with a snapshot of the affected `Game` objects (preserving `ownedPlatformId`, `ownedPlatformName`, `addedAt`).
- `collection-bulk-persistence`: `CollectionRepository.removeMany(List<int>)` using a single `WHERE id IN (?,?,...)` delete, and `addMany(List<Game>)` using a sqflite `Batch` insert with `ConflictAlgorithm.replace`. One `_load()` refresh per bulk operation; `_recsStale` flipped to `true`.
- `analytics-bulk-removal`: A single `bulk_games_removed` analytics event with `count` and `collection_size_after`, fired exactly once per confirmed bulk removal. No individual `game_removed` events are emitted for the bulk action.
- `l10n-multiselect`: New ARB keys (`menuSelectGames`, `nSelected`, `removeNGamesTitle`, `removeNGamesMessage`, `gamesRemoved`) added to `en`, `es`, `fr`, `pt`; generated via `flutter gen-l10n`.
- `tests-multiselect-bulk`: New unit and widget tests covering repo bulk methods, notifier bulk methods (with a fake repo), `GameCoverCard` selection visuals, and an end-to-end `HomeScreen` widget test for the full flow.

### Modified Capabilities

_None._ `openspec/specs/` is empty, so this change is purely additive. The existing single-game `removeGameFlow`, `CollectionNotifier.remove`, `CollectionRepository.remove`, and `restore(Game)` remain unchanged and continue to serve the per-game remove entry points used by `GameDetailScreen` and the search/recommendations screens.

## Impact

- **Files touched:**
  - `lib/screens/home_screen.dart` — convert `_SummaryTab`, add selection state and bulk-remove method, switch the `SliverAppBar` between normal/selection mode, pass selection props to the grid.
  - `lib/widgets/game_cover_card.dart` — add optional `selectable`/`selected`/`onToggleSelection` params; conditional tap target; new selection badge; accent border on `selected`; hide `_QuickAddButton` when `selectable`.
  - `lib/services/collection_repository.dart` — add `removeMany(List<int>)` and `addMany(List<Game>)`.
  - `lib/providers/collection_provider.dart` — add `removeMany(List<int>)` and `restoreMany(List<Game>)` to `CollectionNotifier`.
  - `lib/services/analytics_service.dart` — add `BulkGamesRemovedParams` and `logBulkGamesRemoved(...)`.
  - `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_pt.arb` — new keys.
  - `lib/l10n/app_localizations*.dart` — regenerated by `flutter gen-l10n` (committed).
  - `test/services/collection_repository_test.dart` — new.
  - `test/providers/collection_provider_test.dart` — new.
  - `test/widgets/game_cover_card_test.dart` — new.
  - `test/widgets/bulk_remove_flow_test.dart` — new.
- **No new dependencies.** Only existing sqflite, riverpod, and the app's own analytics layer.
- **Performance:** Selection toggles rebuild the visible portion of the `SliverGrid` (children are already wrapped in `RepaintBoundary` by the default `SliverChildBuilderDelegate`). The selection props on `GameCoverCard` are passed from the parent; no card-level subscription to a selection stream. A typical Shelf fits in the low hundreds; the rebuild cost is negligible.
- **Database:** `removeMany` runs as a single SQL statement; `addMany` runs as a single `batch.commit`. No N+1 deletes; no N+1 analytics writes.
- **Backward compatibility:** `GameCoverCard` keeps its default-off selection params, so Search, Recommendations, and Shared Collections render unchanged. The existing single-game `removeGameFlow` path is untouched.
- **Non-goals:** Multiselect on the Search results grid, the Recommendations grid, or the Shared Collections detail screen. Bulk add (the QR import already handles batch add via `importCollection`). Bulk edit (platform/version). Cross-tab selection persistence.
- **Known trade-off:** The "X selected" counter and the Delete action live in the app bar rather than a bottom action sheet. On a phone the app bar is always reachable and the bottom is occupied by the nav bar, so the app bar is the only consistent surface across phone and tablet (`_SideNav` does not host this).
