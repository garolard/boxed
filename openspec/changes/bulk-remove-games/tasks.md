# Tasks — bulk-remove-games

Reference `proposal.md` for motivation and `specs/**/*.md` for requirements. Each step is a single buildable commit boundary; no step relies on a later step to restore a building state.

## Step 1: Repository bulk methods + test-only DB-opener seam + repo unit test

**Files Affected**: `lib/services/collection_repository.dart`, `test/services/collection_repository_test.dart`, `pubspec.yaml`

**What Will Be Done**: Add `Future<void> removeMany(List<int> ids)` and `Future<void> addMany(List<Game> games)` to `CollectionRepository`. `removeMany`: no-op on empty input; otherwise a single `DELETE FROM collection WHERE id IN (?,?,...)`; if `ids.length > 500`, split the `IN`-clause into chunks of 500 and run every chunk inside one `db.transaction(...)` so the operation stays logically atomic while never exceeding SQLite's variable cap. `addMany`: a sqflite `Batch` of `batch.insert('collection', {'id': g.id, 'name': g.name, 'data': jsonEncode(g.toJson()), 'added_at': g.addedAt.toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace)` per game, then `await batch.commit()` — mirroring the existing single `add` so `ownedPlatformId`/`ownedPlatformName`/`addedAt` round-trip. Add an optional constructor param (e.g. `Future<Database> Function()? opener`, default `null`) that, when set, replaces the lazy `openDatabase(...)` path; production callers pass nothing (current behavior preserved). Add `sqflite_common_ffi` to `dev_dependencies` in `pubspec.yaml`. The new test seeds an in-memory ffi database via the opener, asserts the `removeMany` empty no-op, the mixed present/absent behavior, and the `addMany` overwrite-on-conflict behavior. Reference: `openspec/changes/bulk-remove-games/specs/collection-bulk-persistence/spec.md`.

**Testing Strategy**: `flutter test test/services/collection_repository_test.dart` against in-memory `sqflite_common_ffi`; assert row presence/absence directly via `db.rawQuery('SELECT id FROM collection')`.

## Step 2: Analytics bulk-removal event

**Files Affected**: `lib/services/analytics_service.dart`

**What Will Be Done**: Add a `BulkGamesRemovedParams` typed param class (fields `count`, `collectionSizeAfter`) next to the existing `GameAddedParams`/`GameRemovedParams`, and `Future<void> logBulkGamesRemoved(BulkGamesRemovedParams params)` routed through the existing `_safe(...)` wrapper — emitting one `bulk_games_removed` event with `count` and `collection_size_after`. No per-game event is emitted here; that is the caller's contract (Step 3). `_safe` already satisfies the `analytics-bulk-removal` robustness requirement (analytics failure never blocks the removal). Reference: `openspec/changes/bulk-remove-games/specs/analytics-bulk-removal/spec.md`.

**Testing Strategy**: Verified indirectly via the notifier test in Step 3 (one event, correct `count`/`collection_size_after`, no per-game events). No standalone analytics test in this change.

## Step 3: Notifier bulk methods + notifier unit test (FakeCollectionRepository + FakeAnalytics)

**Files Affected**: `lib/providers/collection_provider.dart`, `test/providers/collection_provider_test.dart`

**What Will Be Done**: Add `Future<List<Game>> removeMany(List<int> ids)` and `Future<void> restoreMany(List<Game> snapshot)` to `CollectionNotifier`. `removeMany`: snapshot `state.games.where((g) => ids.contains(g.id))` BEFORE delegating; call `_repo.removeMany(ids)`; set `_recsStale = true`; `await _load()`; fire exactly one `bulk_games_removed` event via `_analytics.logBulkGamesRemoved(BulkGamesRemovedParams(count: snapshot.length, collectionSizeAfter: state.games.length - snapshot.length))` (compute post-size from the refreshed state — assert in test); return the snapshot. `restoreMany`: call `_repo.addMany(snapshot)`; set `_recsStale = true`; `await _load()`; fire NO analytics (mirrors `restore`). The test creates a `test/providers/` directory (none exists today), defines inline `_FakeCollectionRepository extends CollectionRepository` (overrides `getAll`/`add`/`remove`/`removeMany`/`addMany` with in-memory `Map<int, Game>`, never calls `super`/`_database`) and inline `_FakeAnalytics implements AnalyticsService` (records `logBulkGamesRemoved` calls, `noSuchMethod` fallback for the rest — mirror `test/services/review_service_test.dart`), and overrides `collectionRepositoryProvider`/`analyticsServiceProvider`/`igdbServiceProvider`/`reviewServiceProvider` so `build()` runs for real against the fakes. Asserts: `removeMany` snapshots before deleting (fake repo received the same ids; returned snapshot matches), fires exactly one `bulk_games_removed` with correct `count`/`collection_size_after`; `restoreMany` re-adds and fires no analytics. Reference: `openspec/changes/bulk-remove-games/specs/tests-multiselect-bulk/spec.md`.

**Testing Strategy**: `flutter test test/providers/collection_provider_test.dart`; pump/wait for `build()`'s async `_load()` to settle before invoking `removeMany`.

## Step 4: GameCoverCard selection visuals + card widget test

**Files Affected**: `lib/widgets/game_cover_card.dart`, `test/widgets/game_cover_card_test.dart`

**What Will Be Done**: Add three optional, default-preserving params to `GameCoverCard`: `bool selectable = false`, `bool selected = false`, `VoidCallback? onToggleSelection`. When `selectable` is true: `InkWell.onTap` calls `onToggleSelection` instead of pushing `GameDetailScreen`; the top-right `_OwnedPill` is replaced by a selection badge (empty ring `Icons.check_circle_outline_rounded` when `selected == false`, filled `Icons.check_circle_rounded` with `AppColors.accent` + white check when `selected == true`); the per-card `_QuickAddButton` is not rendered; a 3 px `AppColors.accent` border wraps the card when `selected == true`. When `selectable == false`, behavior is identical to today (existing callers — home_screen before Step 6, search/recommendations/shared-collections — render unchanged). The new test renders the card in `selectable: true` mode and asserts the empty badge + no border for `selected: false`, and the filled checkmark badge + accent border for `selected: true`. Reference: `openspec/changes/bulk-remove-games/specs/shelf-multiselect/spec.md`.

**Testing Strategy**: `flutter test test/widgets/game_cover_card_test.dart` in a `MaterialApp` with `AppLocalizations.localizationsDelegates` + `supportedLocales` (existing pattern); assert badge icon and border presence via `Finder`.

## Step 5: l10n — add 5 keys to all 6 ARBs + regenerate localizations

**Files Affected**: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_pt.arb`, `lib/l10n/app_pt_BR.arb`, `lib/l10n/app_pt_PT.arb`, `lib/l10n/app_localizations*.dart`

**What Will Be Done**: Add `menuSelectGames` (tooltip string), `nSelected(int count)` ({count, plural, =1{...} other{...}}), `removeNGamesTitle(int count)`, `removeNGamesMessage`, `gamesRemoved(int count)` to all six ARB files. `app_en.arb` carries `@`-metadata + placeholders (template); `app_pt.arb`/`app_pt_BR.arb`/`app_pt_PT.arb` carry values + `@`-metadata (their existing convention); `app_es.arb`/`app_fr.arb` carry values-only (their convention). Plural strings use `=1`/`other` only, matching `gamesInShelf`. Run `flutter gen-l10n` and commit the regenerated `lib/l10n/app_localizations*.dart` (per CLAUDE.md). No UI references the new getters yet — that lands in Step 6. Reference: `openspec/changes/bulk-remove-games/specs/l10n-multiselect/spec.md`.

**Testing Strategy**: `flutter gen-l10n` succeeds; `flutter analyze` passes (unused public getters are fine); spot-check that `AppLocalizations.{en,es,fr,pt,pt_BR,pt_PT}` all gained the five members.

## Step 6: HomeScreen `_SummaryTab` selection mode + inline bulk-remove flow

**Files Affected**: `lib/screens/home_screen.dart`

**What Will Be Done**: Convert `_SummaryTab` from `ConsumerWidget` to `ConsumerStatefulWidget` holding `Set<int> _selectedIds` (local, cleared on entry/Close/confirm; D1). Add an `IconButton`(`Icons.checklist_rounded`, tooltip `context.l10n.menuSelectGames`) to the Shelf `SliverAppBar` actions that enters selection mode (clears the set, flips a `_inSelectionMode` flag). In selection mode the app bar morphs: title becomes `context.l10n.nSelected(_selectedIds.length)`; actions become **Close** (exits selection, clears the set) and **Delete** (disabled when 0 selected); the existing `PopupMenuButton` is hidden. Pass `selectable: _inSelectionMode`, `selected: _selectedIds.contains(game.id)`, `onToggleSelection: () => _toggle(game.id)` to each `GameCoverCard` (D4 params from Step 4). The Delete action runs the inline flow (D6): capture `ScaffoldMessenger` before awaiting; `showDialog<bool>` an `AlertDialog` (`context.l10n.removeNGamesTitle(n)` / `context.l10n.removeNGamesMessage`, `AppColors.surfaceHi`/`AppColors.danger`); on `true`, `final snapshot = await notifier.removeMany(_selectedIds.toList())`; exit selection mode; show a 5s `SnackBar` (`persist: false`) `context.l10n.gamesRemoved(n)` with `SnackBarAction` label `context.l10n.undo` → `notifier.restoreMany(snapshot)`. Mirror `lib/widgets/remove_game_flow.dart`'s structure. Reference: `openspec/changes/bulk-remove-games/specs/shelf-multiselect/spec.md`, `openspec/changes/bulk-remove-games/specs/bulk-remove-flow/spec.md`.

**Testing Strategy**: Manual + the end-to-end widget test in Step 7. `flutter analyze` must pass (the new `context.l10n.*` getters exist from Step 5; `notifier.removeMany`/`restoreMany` from Step 3; `GameCoverCard` params from Step 4).

## Step 7: End-to-end bulk-remove widget test

**Files Affected**: `test/widgets/bulk_remove_flow_test.dart`

**What Will Be Done**: Drive the Shelf from selection entry through confirm and undo, mirroring the `_StubCollection extends CollectionNotifier` pattern from `test/widgets/remove_game_flow_test.dart` (override `build()` to skip sqflite + override `removeMany`/`restoreMany` to mutate the stub's `CollectionState.games`; override `collectionProvider` with `collectionProvider.overrideWith(() => stub)`). Pump `HomeScreen` in a `MaterialApp` with `AppLocalizations.localizationsDelegates` + `supportedLocales`; tap the selection entry `IconButton`; tap N covers to select; tap Delete; confirm the dialog; assert the N games leave the Shelf; tap Undo on the `SnackBar`; assert all N games return in their prior state. Reference: `openspec/changes/bulk-remove-games/specs/tests-multiselect-bulk/spec.md`.

**Testing Strategy**: `flutter test test/widgets/bulk_remove_flow_test.dart`; use `tester.pumpAndSettle()` around the async notifier calls and stepped pumps for the snackbar's 5s window as in `remove_game_flow_test.dart`.

## Required Documentation

### Local files

- lib/providers/collection_provider.dart
- lib/providers/services.dart
- lib/services/collection_repository.dart
- lib/services/analytics_service.dart
- lib/services/review_service.dart
- lib/services/igdb_service.dart
- lib/screens/home_screen.dart
- lib/screens/game_detail_screen.dart
- lib/widgets/game_cover_card.dart
- lib/widgets/remove_game_flow.dart
- lib/widgets/add_game_flow.dart
- lib/widgets/share_qr_sheet.dart
- lib/theme/app_theme.dart
- lib/theme/responsive.dart
- lib/l10n/l10n.dart
- lib/l10n/app_en.arb
- lib/l10n/app_es.arb
- lib/l10n/app_fr.arb
- lib/l10n/app_pt.arb
- lib/l10n/app_pt_BR.arb
- lib/l10n/app_pt_PT.arb
- lib/l10n/app_localizations.dart
- lib/l10n/app_localizations_en.dart
- lib/models/game.dart
- lib/main.dart
- l10n.yaml
- pubspec.yaml
- test/fakes/fake_firestore.dart
- test/fakes/fake_auth.dart
- test/services/review_service_test.dart
- test/services/scan_quota_service_test.dart
- test/services/igdb_service_test.dart
- test/services/purchase/fake_purchase_service.dart
- test/services/purchase/premium_bridge_test.dart
- test/widgets/remove_game_flow_test.dart
- test/widgets/share_qr_sheet_test.dart

### Spec files

- openspec/changes/bulk-remove-games/proposal.md
- openspec/changes/bulk-remove-games/specs/bulk-remove-flow/spec.md
- openspec/changes/bulk-remove-games/specs/shelf-multiselect/spec.md
- openspec/changes/bulk-remove-games/specs/collection-bulk-persistence/spec.md
- openspec/changes/bulk-remove-games/specs/analytics-bulk-removal/spec.md
- openspec/changes/bulk-remove-games/specs/l10n-multiselect/spec.md
- openspec/changes/bulk-remove-games/specs/tests-multiselect-bulk/spec.md

### External URLs

None

## Implementation Context

**Stack**: Flutter 3+, Dart; Riverpod 3.x (`NotifierProvider`); sqflite (`boxed.db` v2, table `collection(id PK, name, data, added_at)`); `intl` 0.20.2 + `flutter_localizations` (generate via `l10n.yaml`, template `app_en.arb`); Firebase Analytics/Crashlytics behind `AnalyticsService._safe`. Dark theme only; supported locales en/es/fr/pt/pt_BR/pt_PT.

**Conventions** (project-specific, non-obvious):

- DI seam: shared singletons in `lib/providers/services.dart`; four throw-by-default and overridden in `main.dart`'s `ProviderScope`. `CollectionNotifier` reads its deps in `build()` via `ref.read` — overriding the providers is enough to isolate it (CLAUDE.md).
- `CollectionRepository` is a concrete class with a lazy private `_database` getter (`openDatabase` only on first method use); public methods are instance methods that call `await _database` inside their bodies. Single `add` uses `ConflictAlgorithm.replace`.
- `CollectionNotifier` stores `_repo` as `late final` assigned in `build()`. Every mutation sets `_recsStale = true` then calls `_load()`. `restore(Game)` deliberately fires NO analytics (undo policy).
- Typed analytics: events go through typed param classes + `AnalyticsService.logXxx`, never loose maps; `_safe` swallows all errors so analytics never blocks the caller.
- Confirm+undo UX is inline in `lib/widgets/remove_game_flow.dart`: `showDialog<bool>` + `AlertDialog` (`AppColors.surfaceHi`/`AppColors.danger`) → notifier call → `ScaffoldMessenger.showSnackBar` (5s, `persist: false`) with `SnackBarAction` Undo. Capture the messenger BEFORE awaiting the notifier. No shared dialog/snackbar helper exists.
- l10n: `generate: true` + `l10n.yaml`; the generated `lib/l10n/app_localizations*.dart` are COMMITTED. Access via `context.l10n` (`lib/l10n/l10n.dart`). `@`-metadata matters only in the template; pt-family files carry it redundantly, es/fr omit it.
- Tests: widget tests stub the notifier via `_StubCollection extends CollectionNotifier` (override `build()` to skip sqflite + override methods, override `collectionProvider`). Service tests use fakes implementing interfaces (`FakePurchaseService implements PurchaseService`). `review_service_test.dart` has `_FakeAnalytics implements AnalyticsService` with a `noSuchMethod` fallback.

**Avoid**:

- Don't put selection state in `CollectionNotifier` — it's ephemeral and Shelf-scoped; keep it local to `_SummaryTab`.
- Don't emit per-game analytics events for bulk removal — one summary `bulk_games_removed` event only; undo fires nothing.
- Don't extract a `CollectionRepository` interface just for testing — Dart virtual methods + the lazy `_database` getter let a subclass fake avoid sqflite without interface ceremony.
- Don't add the 5 l10n keys to only en/es/fr/pt — `supportedLocales` lists 6; add to `pt_BR`/`pt_PT` too to preserve key parity.
- Don't use full CLDR plural forms — the project convention is `=1`/`other` (see `gamesInShelf`).
- Don't change the `collection` table schema — `addMany` reuses the existing `add` path (`ConflictAlgorithm.replace`) so owned-platform/`addedAt` round-trip.
- Don't reach for a shared dialog/snackbar helper — none exists; mirror `remove_game_flow` inline.
