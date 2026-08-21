# Design — bulk-remove-games

## Context

The Shelf removes one game at a time via `removeGameFlow` (`lib/widgets/remove_game_flow.dart:15`) — a confirm `AlertDialog` plus a 5-second undo `SnackBar`. Pruning a collection (re-buy, move, clean-out) means repeating that flow per title. This change adds multi-selection on the Shelf and a single confirmed bulk-remove with one batch-undo.

The change is purely additive (per `proposal.md`): `openspec/specs/` is empty, so nothing is modified at the spec level. The single-game `removeGameFlow`, `CollectionNotifier.remove`, `CollectionRepository.remove`, and `restore(Game)` stay untouched and keep serving `GameDetailScreen` and the search/recommendations screens.

Relevant codebase facts (from the discovery subagent — single source of truth for this design):

- `lib/services/collection_repository.dart` — concrete `class CollectionRepository` with a lazy `Database? _db` + private `Future<Database> get _database async` getter that calls `openDatabase(...)` only on first use. Public methods (`getAll`, `add(Game)` with `ConflictAlgorithm.replace`, `remove(int)` with `where: 'id = ?'`) are instance methods that call `await _database` inside their bodies. No existing `Batch` / `WHERE id IN` / `removeMany` / `addMany` symbols anywhere in `lib/`. Table: `collection(id PK, name, data [Game.toJson snapshot], added_at)`. No schema change is needed.
- `lib/providers/collection_provider.dart` — `CollectionNotifier` holds `late final CollectionRepository _repo` assigned in `build()` via `ref.read(collectionRepositoryProvider)`. Every mutation (`add`/`remove`/`restore`/`importCollection`) sets `_recsStale = true` then calls `_load()`. `remove(int)` snapshots `state.games.firstWhere((g) => g.id == gameId)` before `_repo.remove`. `restore(Game)` deliberately fires **no** analytics (undo policy, confirmed in code comments at `collection_provider.dart:137-144`).
- `lib/providers/services.dart` — `collectionRepositoryProvider` is `Provider<CollectionRepository>((ref) => CollectionRepository())`, concrete, **not** overridden in `main.dart` (unlike the four throw-by-default providers). `analyticsServiceProvider` throws by default and is overridden in `main.dart` + tests.
- `lib/services/analytics_service.dart` — every `log*` method wraps its body in `_safe(...)` which swallows all errors, so analytics never blocks the caller. Events use typed param classes (`GameAddedParams`, `GameRemovedParams`, …), never loose maps.
- `lib/widgets/game_cover_card.dart` — `GameCoverCard` is a `ConsumerWidget`; `InkWell.onTap` pushes `GameDetailScreen`; top-right `_OwnedPill`; per-card `_QuickAddButton`. No `selectable`/`selected`/`onToggleSelection`/`_selectedIds`/`checklist_rounded`/`bulk_games`/`BulkGames` symbols exist anywhere — selection mode is genuinely new.
- `lib/screens/home_screen.dart` — `_SummaryTab` (line 242) is a `ConsumerWidget`; `SliverAppBar` with an `IconButton` (shared collections) + `PopupMenuButton` (share/export/import); `SliverGrid` using `context.coverExtent`.
- `lib/widgets/remove_game_flow.dart` — canonical confirm+undo pattern: `showDialog<bool>` + `AlertDialog` (`AppColors.surfaceHi`, `AppColors.danger`) → notifier call → `messenger.showSnackBar` (5s, `persist: false`) with `SnackBarAction` Undo → `notifier.restore`. Messenger is captured **before** awaiting the notifier. There is **no** shared dialog/snackbar/bottom-sheet helper — confirmations are inline in `remove_game_flow.dart` and `shared_collections_screen.dart`.
- `lib/theme/app_theme.dart` — `AppColors.accent = 0xFFA78BFA`, `AppColors.danger`, `surfaceHi`; `snackBarTheme` already matches `remove_game_flow`'s snackbar.
- `lib/l10n/` — six ARB files exist: `app_en.arb` (template, `@`-metadata), `app_es.arb`/`app_fr.arb` (values-only), `app_pt.arb`/`app_pt_BR.arb`/`app_pt_PT.arb` (values + `@`-metadata). `supportedLocales` lists 6 entries. The only existing plural string is `gamesInShelf` using `{count, plural, =1{...} other{...}}` across all locales. `generate: true` + `l10n.yaml` (template `app_en.arb`); generated `app_localizations*.dart` are committed. Access via `context.l10n`.
- Tests — no `test/providers/` directory exists; `test/widgets/remove_game_flow_test.dart` stubs the notifier via `_StubCollection extends CollectionNotifier` (overrides `build()` to skip sqflite + overrides `remove`/`restore`, overrides `collectionProvider` with `collectionProvider.overrideWith(() => stub)`). `test/services/purchase/fake_purchase_service.dart` is the interface+fake pattern (`FakePurchaseService implements PurchaseService`). `test/services/review_service_test.dart` has `_FakeAnalytics implements AnalyticsService` with `noSuchMethod` fallback.

## Goals / Non-Goals

**Goals**

- A visible, Shelf-scoped multiselect entry in the app bar that morphs the app bar between normal and selection modes.
- One confirmed bulk remove that deletes every selected game in a single DB operation, with one batch-undo that restores the exact `ownedPlatformId`/`ownedPlatformName`/`addedAt` of every removed entry.
- Exactly one `bulk_games_removed` analytics event per confirmed removal (with `count` + `collection_size_after`); no per-game events; undo emits nothing.
- Localized strings in every supported locale.
- Unit + widget test coverage at the repo, notifier, card, and end-to-end levels.

**Non-Goals** (from `proposal.md`)

- Multiselect on Search, Recommendations, or Shared Collections.
- Bulk add (QR import already handles batch add via `importCollection`).
- Bulk edit (platform/version).
- Cross-tab selection persistence.
- Touching the single-game `removeGameFlow` path or `GameDetailScreen`.

## Decisions

### D1: Selection state is local to `_SummaryTab` (`Set<int> _selectedIds`), not in `CollectionNotifier` or a separate provider

ADR/DDR: **all three apply.** (1) Moving it later is a refactor across the notifier/contracts. (2) A future reader might expect ephemeral UI selection to live in the state container. (3) Real alternatives existed.

- **Alternatives considered**:
  - (a) Put selection in `CollectionNotifier`/`CollectionState` — **rejected**: selection would survive tab switches and navigation, leaking into Search/Recommendations and violating the `shelf-multiselect` scope requirement; it also pollutes the immutable collection state with UI-only concerns and forces every `copyWith` consumer to carry it.
  - (b) A dedicated `SelectionNotifier` Riverpod provider — **rejected**: the selection is watched only inside `_SummaryTab`; a provider adds watching/reframe overhead for ephemeral state that doesn't need cross-widget subscription.
- **Chosen**: local `Set<int> _selectedIds` in `_SummaryTab` (converted to `ConsumerStatefulWidget`). Cleared on entry (spec: "existing selection is cleared on entry"), on Close, and after confirm. It lives only for the Shelf tab's lifetime and never touches `CollectionState`.

### D2: `removeMany(List<int>) → Future<List<Game>>` returns the snapshot; the UI passes it to `restoreMany(List<Game>)` on undo

ADR/DDR: **all three apply.** (1) The signature affects notifier, tests, and UI. (2) Single-game `remove(int)` returns `void` and the flow captures the `Game` from its own context — bulk is asymmetric. (3) Real alternatives existed.

- **Alternatives considered**:
  - (a) `removeMany` returns `void`; the UI resolves the selected ids to `Game` objects from the watched collection state before calling — **rejected**: duplicates snapshot logic in the widget, risks staleness if state changes between read and call, and the UI would have to preserve owned-platform/`addedAt` manually.
  - (b) Snapshot stored internally in the notifier; `restoreMany()` takes no args — **rejected**: conflicts with the `tests-multiselect-bulk` scenario requiring `restoreMany(List<Game>)` to receive the batch, and makes the notifier implicitly stateful across operations.
- **Chosen**: `CollectionNotifier.removeMany(List<int>)` snapshots `state.games.where((g) => ids.contains(g.id))` (entries already carry `ownedPlatformId`/`ownedPlatformName`/`addedAt`), calls `_repo.removeMany(ids)`, sets `_recsStale = true`, calls `_load()`, fires one analytics event, and returns the snapshot. The bulk-remove flow captures the returned list and passes it to `restoreMany(snapshot)` on Undo. Satisfies the `tests-multiselect-bulk` scenario "the returned snapshot contains the matching Game objects."

### D3: `removeMany` = single `DELETE ... WHERE id IN (?,?,...)`; `addMany` = sqflite `Batch` of inserts with `ConflictAlgorithm.replace`; add a test-only DB-opener seam

ADR/DDR: partial — not hard to reverse, not surprising. Brief rationale, plus a test-seam note.

- `removeMany` runs one `DELETE FROM collection WHERE id IN (?,?,...)` so the spec's "single database operation" holds. `addMany` runs one sqflite `Batch` of `insert(..., conflictAlgorithm: ConflictAlgorithm.replace)` calls, mirroring the existing single `add` so `ownedPlatformId`/`ownedPlatformName`/`addedAt` round-trip on undo. Empty input is a no-op for `removeMany`.
- **Test seam**: `CollectionRepository` gains an optional constructor param (e.g. `Future<Database> Function()? _opener` or an injectable `dbPath`/`factory`), default `null` → current behavior (lazy `openDatabase` on `boxed.db`). No existing caller changes. The repo unit test passes an opener that returns an in-memory `sqflite_common_ffi` database, enabling real SQL verification of `removeMany`/`addMany` without touching the filesystem. This is an additive, non-breaking contract change scoped to enabling the `tests-multiselect-bulk` repo-level scenarios.

### D4: Exactly one `bulk_games_removed` event per confirmed removal; undo fires nothing

ADR/DDR: **all three apply.** (1) Analytics taxonomy changes affect downstream consumers. (2) The no-event-on-undo rule mirrors single-game policy but is easy to forget for bulk. (3) Real alternatives existed.

- **Alternatives considered**:
  - (a) Emit N `game_removed` events (one per game) — **rejected**: `analytics-bulk-removal` explicitly forbids it; also N analytics writes on the caller's path.
  - (b) One summary event plus per-game events for attribution — **rejected**: same noise, no extra value over `count` + `collection_size_after`.
- **Chosen**: `BulkGamesRemovedParams(count, collectionSizeAfter)` + `AnalyticsService.logBulkGamesRemoved(...)` routed through the existing `_safe` wrapper, so the `analytics-bulk-removal` robustness requirement ("analytics failure does not block the removal") is already satisfied by `_safe` swallowing errors — no new retry/blocking logic. `restoreMany` fires nothing, mirroring `restore`.

### D5: Testability — `FakeCollectionRepository extends CollectionRepository` (subclass override), no interface extraction

ADR/DDR: **all three apply.** (1) The test-double shape is hard to reverse once tests depend on it. (2) Surprising: the project HAS the `abstract class PurchaseService` + `FakePurchaseService implements PurchaseService` pattern, and this decision deliberately does **not** apply it to `CollectionRepository`. (3) Real alternatives existed.

- **Alternatives considered**:
  - (a) Extract `abstract class CollectionRepository` interface + rename the concrete to `CollectionRepositoryImpl`; change `collectionRepositoryProvider` and `CollectionNotifier._repo` to the interface type; tests provide `FakeCollectionRepository implements CollectionRepository` — **rejected**: larger contract change touching `lib/providers/services.dart`, `lib/providers/collection_provider.dart`, and every reference, for zero functional benefit. The lazy `_database` getter (called only inside each method body) already lets a subclass override `getAll`/`add`/`remove`/`removeMany`/`addMany` without ever triggering `openDatabase`.
  - (b) Stub the notifier (`_StubCollection`-style, override `build` + `removeMany`/`restoreMany`) — **rejected**: the `tests-multiselect-bulk` scenario "the fake repository's bulk delete received the same ids" requires verifying real delegation to a fake repo, which a notifier stub cannot prove.
- **Chosen**: a test-only `FakeCollectionRepository extends CollectionRepository` overrides `getAll`/`add`/`remove`/`removeMany`/`addMany` with in-memory `Map<int, Game>` storage and **never** calls `super` or `_database` (so `openDatabase` is never reached). The notifier unit test overrides `collectionRepositoryProvider` (+ `analyticsServiceProvider` with a `_FakeAnalytics`, + `igdbServiceProvider`/`reviewServiceProvider` with no-op fakes) so `CollectionNotifier.build()` runs for real against the fake repo — verifying true delegation, snapshotting, and the single `bulk_games_removed` event. This mirrors the project's existing "override the provider to isolate" DI seam (CLAUDE.md) without the interface ceremony.

### D6: Bulk-remove UX is an inline confirm+undo flow mirroring `remove_game_flow`, not a new shared helper

ADR/DDR: partial — not hard to reverse, not surprising (follows the existing inline pattern). Brief rationale.

- The project has no shared dialog/snackbar helper; confirmations are inline in `remove_game_flow.dart` and `shared_collections_screen.dart`. A second inline instance (tap Delete → `AlertDialog` `removeNGamesTitle(n)` / `removeNGamesMessage` → `notifier.removeMany` → exit selection mode → 5s `SnackBar` `gamesRemoved(n)` with Undo → `restoreMany(snapshot)`) is consistent; extracting a generic confirm+undo helper for one extra call site is YAGNI. The `ScaffoldMessenger` is captured before awaiting the notifier, exactly as `remove_game_flow` does.

### D7: Localize all 6 supported locales (en, es, fr, pt, pt_BR, pt_PT), not just the 4 named in the proposal

ADR/DDR: **all three apply.** (1) Adding locales later is easy, but the parity decision sets a precedent. (2) Surprising: the proposal explicitly says "all four ARBs (en, es, fr, pt)". (3) Real alternatives existed.

- **Alternatives considered**:
  - (a) Add the 5 keys only to `en`/`es`/`fr`/`pt`; let `pt_BR`/`pt_PT` fall back to `pt` via Flutter locale resolution at runtime — **rejected**: the existing `app_pt.arb`/`app_pt_BR.arb`/`app_pt_PT.arb` maintain full key parity, and breaking that parity for new keys is inconsistent. The `l10n-multiselect` spec SHALL "every locale the app already supports," and `AppLocalizations.supportedLocales` lists 6.
  - (b) Add to `pt_BR`/`pt_PT` only if their translations diverge from `pt` — **rejected**: same parity argument; the keys should exist in every locale file so `gen-l10n` emits the abstract members for each.
- **Chosen**: add the 5 keys to all 6 ARBs. `pt_BR`/`pt_PT` values may initially mirror `pt` (as they do for existing keys) and diverge later; the keys are present so resolution never falls back and parity is preserved.

### D8: ARB `@`-metadata follows each file's existing convention

ADR/DDR: partial — not hard to reverse, not surprising. Brief rationale.

- `gen-l10n` reads placeholder metadata from the template (`app_en.arb`) only; non-template `@`-metadata is redundant. To keep diffs consistent with each file's current style: `app_en.arb` gets `@`-metadata (required, it's the template); `app_pt.arb`/`app_pt_BR.arb`/`app_pt_PT.arb` get values + `@`-metadata (matching their current convention); `app_es.arb`/`app_fr.arb` get values-only (matching theirs).

### D9: Plural forms use `=1`/`other` across all locales, matching `gamesInShelf`

ADR/DDR: partial — not hard to reverse, not surprising (follows convention). Brief rationale.

- `l10n-multiselect` requires "the project's existing intl plural rules." The only existing plural string (`gamesInShelf`) uses `{count, plural, =1{...} other{...}}` in every locale. `nSelected(count)`, `removeNGamesTitle(count)`, and `gamesRemoved(count)` follow the same form in every ARB. Full CLDR plural sets are not warranted by the project's established style.

### D10: Both `removeMany` and `restoreMany` set `_recsStale = true` before `_load()`

ADR/DDR: minimal — not hard to reverse, not surprising. Brief rationale.

- Mirrors every existing mutation (`add`/`remove`/`restore`/`importCollection`), satisfying `collection-bulk-persistence` "first bulk op marks recs stale." No new mechanism.

## Risks / Trade-offs

- **[SQLite variable cap (default `SQLITE_MAX_VARIABLE_NUMBER` = 999)]** → Mitigation: if `ids.length` exceeds a threshold (500, conservative), chunk the `IN (?,?,...)` clause and execute all chunks inside a single `db.transaction(...)` so the operation stays logically atomic from the caller's view while never exceeding the limit. The Shelf is "low hundreds" per `proposal.md`, so chunking is a defensive fallback, not the expected path.
- **[Selection toggles rebuild visible `SliverGrid` children]** → Mitigation: children are already wrapped in `RepaintBoundary` by the default `SliverChildBuilderDelegate`; selection props come from the parent, with no per-card stream subscription. Negligible at low-hundreds scale. No action.
- **[Undo window bounded by the 5s snackbar lifetime]** → Matches single-game policy; after dismissal the removal is permanent. Documented behavior, not a defect.
- **[`pt_BR`/`pt_PT` translation quality if values mirror `pt` verbatim]** → Mitigation: translate idiomatically where the locales diverge, or accept `pt`-parity initially (consistent with the existing ARBs). The keys exist in both files so divergence can land later without code changes.
- **[Analytics event dropped permanently on transient failure]** → By design (`analytics-bulk-removal` robustness requirement): `_safe` swallows the error so the removal completes; the event is lost, not retried. Accepted trade-off — keeping the operation fast and non-blocking.
- **[`addMany` with `ConflictAlgorithm.replace` overwrites any row with the same id]** → Correct for undo (restores owned-platform/`addedAt`). IGDB ids are stable, so a collision with a different game is impossible; documented for completeness only.

## Migration Plan

- **No data migration**: the `collection` table schema is unchanged; `removeMany`/`addMany` operate on the existing `id`/`name`/`data`/`added_at` columns.
- **No feature flag**: the change is additive. `GameCoverCard`'s new params are default-off, so Search, Recommendations, and Shared Collections render unchanged; the single-game `removeGameFlow` path is untouched.
- **Deploy**: ship the new code + the regenerated `lib/l10n/app_localizations*.dart`. Run `flutter pub get` (one new dev-dependency, `sqflite_common_ffi`, test-only) and `flutter gen-l10n` (per CLAUDE.md, commit the generated files).
- **Rollback**: revert the commit. The single-game remove path continues to work; no schema or data backfill is involved.

## Open Questions

None remain. Every question surfaced during codebase research was resolved from the codebase:

- No existing `Batch`/`WHERE id IN`/`removeMany`/`addMany` → new methods required (D3).
- No existing selection mode anywhere → genuinely new (D1).
- `restore` no-analytics policy → confirmed; mirrored (D4).
- `_recsStale` contract → confirmed; mirrored (D10).
- `AnalyticsService._safe` swallows failures → satisfies the robustness requirement (D4).
- Locale count is 6, not 4 → resolved by the spec SHALL + `supportedLocales` (D7).
- Plural convention → resolved by the `gamesInShelf` precedent (D9).
- Repo testability seam → resolved by the lazy `_database` getter enabling a subclass fake (D5).
