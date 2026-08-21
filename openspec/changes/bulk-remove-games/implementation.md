# Bulk-remove games

## Goal

Add multi-selection to the Shelf tab and a single confirmed bulk-remove action with batch-undo.

## Prerequisites

- Detect the current git branch with `git rev-parse --abbrev-ref HEAD` (or equivalent). If the command returns empty (detached HEAD), use the literal text `detached HEAD` for option 2.
- Present exactly three options in the user's input language (English fallback), in this fixed order. Canonical English labels — translate to match the user's input language, preserving meaning and order:
  1. `Suggest branch "bulk-remove-games"` — the change-name-derived branch (default).
  2. `Stay on current branch "{current-branch}"` — the detected current branch, or `detached HEAD`.
  3. `Enter branch name manually` — free text for a custom branch name.
- No option is prohibited. The user bears full responsibility for the choice.
- If the selected branch does not exist, create it from `main` before implementing.

### Step-by-Step Instructions

#### Step 1: Repository bulk methods + test-only DB-opener seam + repo unit test

*(Testable step — use RED → GREEN)*

##### RED phase

- [x] Add `sqflite_common_ffi: ^2.5.0` to `pubspec.yaml` under `dev_dependencies:` (after `flutter_lints`).

- [x] Create minimal stubs at `lib/services/collection_repository.dart` so the test can compile:

```dart
class CollectionRepository {
  Database? _db;
  final Future<Database> Function()? _opener;

  CollectionRepository({Future<Database> Function()? opener}) : _opener = opener;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    if (_opener != null) {
      _db = await _opener!();
      return _db!;
    }
    // ... rest of existing getter unchanged ...
  }

  // ... existing methods unchanged ...

  Future<void> removeMany(List<int> ids) async {
    // RED stub — does nothing so the test asserts rows still exist
  }

  Future<void> addMany(List<Game> games) async {
    // RED stub — does nothing so the test asserts rows unchanged
  }
}
```

- [x] Write the test into `test/services/collection_repository_test.dart`:

- `removeMany` with empty input is a no-op
- `removeMany` deletes present ids and ignores absent ones
- `removeMany` handles more than 500 ids by chunking inside a transaction
- `addMany` overwrites conflicting entries, preserving owned-platform and `addedAt`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/services/collection_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> _openInMemory() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE collection (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            data TEXT NOT NULL,
            added_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  group('CollectionRepository bulk methods', () {
    late CollectionRepository repo;

    setUp(() {
      repo = CollectionRepository(opener: _openInMemory);
    });

    test('removeMany with empty input is a no-op', () async {
      await repo.add(Game(id: 1, name: 'A', addedAt: DateTime.now()));
      await repo.removeMany([]);
      final games = await repo.getAll();
      expect(games, hasLength(1));
    });

    test('removeMany deletes present ids and ignores absent ones', () async {
      await repo.add(Game(id: 1, name: 'A', addedAt: DateTime.now()));
      await repo.add(Game(id: 2, name: 'B', addedAt: DateTime.now()));
      await repo.add(Game(id: 3, name: 'C', addedAt: DateTime.now()));
      await repo.removeMany([1, 99, 3]);
      final games = await repo.getAll();
      expect(games.map((g) => g.id), [2]);
    });

    test('removeMany chunks at 500 ids inside a transaction', () async {
      for (var i = 1; i <= 600; i++) {
        await repo.add(Game(id: i, name: 'Game $i', addedAt: DateTime.now()));
      }
      await repo.removeMany([for (var i = 1; i <= 600; i++) i]);
      final games = await repo.getAll();
      expect(games, isEmpty);
    });

    test('addMany overwrites conflicting entries', () async {
      final original = Game(
        id: 1,
        name: 'A',
        ownedPlatformName: 'SNES',
        addedAt: DateTime(2024, 1, 1),
      );
      await repo.add(original);
      final updated = Game(
        id: 1,
        name: 'A',
        ownedPlatformName: 'PS1',
        addedAt: DateTime(2024, 6, 1),
      );
      await repo.addMany([updated]);
      final games = await repo.getAll();
      expect(games.single.ownedPlatformName, 'PS1');
      expect(games.single.addedAt, DateTime(2024, 6, 1));
    });
  });
}
```

- [x] Verify RED: run `flutter test test/services/collection_repository_test.dart` — expected: **assertion failures** (exit ≠ 0, failures attributable to the stubbed `removeMany`/`addMany` doing nothing).
- [x] **GATE — DO NOT PROCEED to GREEN until RED is verified.**

##### GREEN phase (only after RED is verified)

- [x] Copy and paste the full implementation into `lib/services/collection_repository.dart`, replacing the RED stubs:

```dart
  Future<void> removeMany(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _database;
    const chunkSize = 500;
    if (ids.length <= chunkSize) {
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        'collection',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } else {
      await db.transaction((txn) async {
        for (var i = 0; i < ids.length; i += chunkSize) {
          final chunk = ids.sublist(
            i,
            i + chunkSize > ids.length ? ids.length : i + chunkSize,
          );
          final placeholders = List.filled(chunk.length, '?').join(',');
          await txn.delete(
            'collection',
            where: 'id IN ($placeholders)',
            whereArgs: chunk,
          );
        }
      });
    }
  }

  Future<void> addMany(List<Game> games) async {
    if (games.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final game in games) {
      final entry = game.copyWith(addedAt: game.addedAt ?? DateTime.now());
      batch.insert(
        'collection',
        {
          'id': entry.id,
          'name': entry.name,
          'data': jsonEncode(entry.toJson()),
          'added_at': entry.addedAt!.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
```

- [x] Verify GREEN: run `flutter test test/services/collection_repository_test.dart` — expected: PASS

##### Step 1 Verification Checklist

**Automated (agent runs before stopping):**
- [x] RED verified — `flutter test test/services/collection_repository_test.dart` fails as expected
- [x] GREEN verified — `flutter test test/services/collection_repository_test.dart` passes
- [x] `flutter analyze` — passes (no new lints)

**Human (verify in browser before committing):**
*(Deferred to Step 6 — no UI changes yet)*

#### Step 1 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 2: Analytics bulk-removal event

*(Non-testable step — standard format, no RED/GREEN needed because the event is verified indirectly in Step 3)*

- [x] Copy and paste into `lib/services/analytics_service.dart`, immediately after the existing `GameRemovedParams` class:

```dart
/// Typed parameter bundle for a bulk removal.
class BulkGamesRemovedParams {
  final int count;
  final int collectionSizeAfter;

  const BulkGamesRemovedParams({
    required this.count,
    required this.collectionSizeAfter,
  });
}
```

- [x] Copy and paste the `logBulkGamesRemoved` method into `AnalyticsService`, placing it immediately after `logGameRemoved`:

```dart
  Future<void> logBulkGamesRemoved(BulkGamesRemovedParams p) async {
    await _safe(() => _analytics.logEvent(
          name: 'bulk_games_removed',
          parameters: {
            'count': p.count,
            'collection_size_after': p.collectionSizeAfter,
          },
        ));
  }
```

##### Step 2 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter analyze` — passes

**Human (verify in browser before committing):**
*(Deferred to Step 6 — analytics event is not yet wired into the UI)*

#### Step 2 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 3: Notifier bulk methods + notifier unit test

*(Testable step — use RED → GREEN)*

##### RED phase

- [x] Create minimal stubs in `lib/providers/collection_provider.dart`, adding these two methods to `CollectionNotifier` after the existing `restore(Game)` method:

```dart
  Future<List<Game>> removeMany(List<int> ids) async {
    // RED stub — returns empty so the test asserts snapshot length
    return [];
  }

  Future<void> restoreMany(List<Game> snapshot) async {
    // RED stub — does nothing so the test asserts state unchanged
  }
```

- [x] Create the directory `test/providers/`.
- [x] Write the test into `test/providers/collection_provider_test.dart`:

- `removeMany` snapshots the affected games and returns them
- `removeMany` delegates to the repository with the same ids
- `removeMany` fires exactly one `bulk_games_removed` event with correct `count` and `collection_size_after`
- `restoreMany` re-adds the supplied entries via the repository
- `restoreMany` fires no analytics event

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/providers/collection_provider.dart';
import 'package:vgcollection/providers/services.dart';
import 'package:vgcollection/services/analytics_service.dart';
import 'package:vgcollection/services/collection_repository.dart';
import 'package:vgcollection/services/igdb_service.dart';
import 'package:vgcollection/services/review_service.dart';

class _FakeCollectionRepository extends CollectionRepository {
  final Map<int, Game> _games = {};

  _FakeCollectionRepository() : super();

  @override
  Future<List<Game>> getAll() async => _games.values.toList();

  @override
  Future<void> add(Game game) async {
    _games[game.id] = game;
  }

  @override
  Future<void> remove(int gameId) async {
    _games.remove(gameId);
  }

  @override
  Future<void> removeMany(List<int> ids) async {
    for (final id in ids) {
      _games.remove(id);
    }
  }

  @override
  Future<void> addMany(List<Game> games) async {
    for (final game in games) {
      _games[game.id] = game;
    }
  }
}

class _FakeAnalytics implements AnalyticsService {
  final List<Map<String, dynamic>> bulkRemovedEvents = [];

  @override
  Future<void> logBulkGamesRemoved(BulkGamesRemovedParams params) async {
    bulkRemovedEvents.add({
      'count': params.count,
      'collectionSizeAfter': params.collectionSizeAfter,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIgdb implements IgdbService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReview implements ReviewService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _createContainer({
  required CollectionRepository repo,
  required AnalyticsService analytics,
}) {
  return ProviderContainer(
    overrides: [
      collectionRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
      igdbServiceProvider.overrideWithValue(_FakeIgdb()),
      reviewServiceProvider.overrideWithValue(_FakeReview()),
    ],
  );
}

Future<void> _waitForLoad(ProviderContainer container) async {
  final completer = Completer<void>();
  final sub = container.listen(collectionProvider, (prev, next) {
    if (next.loaded && !completer.isCompleted) {
      completer.complete();
    }
  });
  if (container.read(collectionProvider).loaded && !completer.isCompleted) {
    completer.complete();
  }
  await completer.future;
  sub.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollectionNotifier bulk methods', () {
    late _FakeCollectionRepository fakeRepo;
    late _FakeAnalytics fakeAnalytics;

    setUp(() {
      fakeRepo = _FakeCollectionRepository();
      fakeAnalytics = _FakeAnalytics();
    });

    test('removeMany snapshots before deleting and returns the snapshot',
        () async {
      final g1 = Game(id: 1, name: 'A', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 1, 1));
      final g2 = Game(id: 2, name: 'B', ownedPlatformName: 'PS1', addedAt: DateTime(2024, 2, 1));
      await fakeRepo.add(g1);
      await fakeRepo.add(g2);

      final container = _createContainer(repo: fakeRepo, analytics: fakeAnalytics);
      final notifier = container.read(collectionProvider.notifier);
      await _waitForLoad(container);

      final snapshot = await notifier.removeMany([1]);

      expect(snapshot, hasLength(1));
      expect(snapshot.single.id, 1);
      expect(snapshot.single.ownedPlatformName, 'SNES');
      expect(fakeRepo._games.containsKey(1), isFalse);
      expect(fakeRepo._games.containsKey(2), isTrue);
    });

    test('removeMany fires exactly one bulk_games_removed event', () async {
      final g1 = Game(id: 1, name: 'A', addedAt: DateTime.now());
      final g2 = Game(id: 2, name: 'B', addedAt: DateTime.now());
      await fakeRepo.add(g1);
      await fakeRepo.add(g2);

      final container = _createContainer(repo: fakeRepo, analytics: fakeAnalytics);
      final notifier = container.read(collectionProvider.notifier);
      await _waitForLoad(container);

      await notifier.removeMany([1, 2]);

      expect(fakeAnalytics.bulkRemovedEvents, hasLength(1));
      expect(fakeAnalytics.bulkRemovedEvents.single['count'], 2);
      expect(fakeAnalytics.bulkRemovedEvents.single['collectionSizeAfter'], 0);
    });

    test('restoreMany re-adds entries and fires no analytics', () async {
      final g1 = Game(id: 1, name: 'A', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 1, 1));
      await fakeRepo.add(g1);

      final container = _createContainer(repo: fakeRepo, analytics: fakeAnalytics);
      final notifier = container.read(collectionProvider.notifier);
      await _waitForLoad(container);

      await notifier.removeMany([1]);
      expect(fakeRepo._games, isEmpty);

      await notifier.restoreMany([g1]);

      expect(fakeRepo._games.containsKey(1), isTrue);
      expect(fakeRepo._games[1]!.ownedPlatformName, 'SNES');
      expect(fakeAnalytics.bulkRemovedEvents, hasLength(1));
    });
  });
}
```

- [x] Verify RED: run `flutter test test/providers/collection_provider_test.dart` — expected: **assertion failures** (exit ≠ 0, failures attributable to the stubbed `removeMany` returning `[]` and `restoreMany` doing nothing).
- [x] **GATE — DO NOT PROCEED to GREEN until RED is verified.**

##### GREEN phase (only after RED is verified)

- [x] Replace the RED stubs in `lib/providers/collection_provider.dart` with the full implementation:

```dart
  Future<List<Game>> removeMany(List<int> ids) async {
    final snapshot = state.games.where((g) => ids.contains(g.id)).toList();
    await _repo.removeMany(ids);
    _recsStale = true;
    await _load();
    await _analytics.logBulkGamesRemoved(BulkGamesRemovedParams(
      count: snapshot.length,
      collectionSizeAfter: state.games.length,
    ));
    return snapshot;
  }

  Future<void> restoreMany(List<Game> snapshot) async {
    await _repo.addMany(snapshot);
    _recsStale = true;
    await _load();
  }
```

- [x] Verify GREEN: run `flutter test test/providers/collection_provider_test.dart` — expected: PASS

##### Step 3 Verification Checklist

**Automated (agent runs before stopping):**
- [x] RED verified — `flutter test test/providers/collection_provider_test.dart` fails as expected
- [x] GREEN verified — `flutter test test/providers/collection_provider_test.dart` passes
- [x] `flutter analyze` — passes

**Human (verify in browser before committing):**
*(Deferred to Step 6 — notifier methods are not yet wired to the UI)*

#### Step 3 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 4: GameCoverCard selection visuals + card widget test

*(Testable step — use RED → GREEN)*

##### RED phase

- [x] Add the new optional params to `lib/widgets/game_cover_card.dart` so the test can compile. The `GameCoverCard` constructor becomes:

```dart
  const GameCoverCard({
    super.key,
    required this.game,
    this.subtitle,
    this.dense = false,
    this.onAddPressed,
    this.selectable = false,
    this.selected = false,
    this.onToggleSelection,
  });
```

Add the field declarations:
```dart
  final bool selectable;
  final bool selected;
  final VoidCallback? onToggleSelection;
```

In `build()`, leave the body **unchanged** for RED (the existing `_OwnedPill` and `InkWell.onTap` push behaviour stay as-is, so the test asserts the selection badge is missing and the test fails).

- [x] Write the test into `test/widgets/game_cover_card_test.dart`:

- Unselected cover in selectable mode shows empty selection badge (`Icons.check_circle_outline_rounded`) and no accent border
- Selected cover in selectable mode shows filled selection badge (`Icons.check_circle_rounded`) with accent color and a 3 px accent border
- Non-selectable mode renders unchanged (existing `_OwnedPill` still visible)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/widgets/game_cover_card.dart';
import 'package:vgcollection/theme/app_theme.dart';

void main() {
  Widget _pumpCard(WidgetTester tester, {
    required bool selectable,
    required bool selected,
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GameCoverCard(
            game: const Game(id: 1, name: 'Test Game'),
            selectable: selectable,
            selected: selected,
            onToggleSelection: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('unselected selectable cover shows empty badge and no accent border',
      (tester) async {
    await tester.pumpWidget(_pumpCard(tester, selectable: true, selected: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(GameCoverCard), matching: find.byType(Container)).first,
    );
    final border = container.decoration! as BoxDecoration;
    expect(border.border!.top.width, lessThan(3));
  });

  testWidgets('selected selectable cover shows filled badge and accent border',
      (tester) async {
    await tester.pumpWidget(_pumpCard(tester, selectable: true, selected: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(GameCoverCard), matching: find.byType(Container)).first,
    );
    final border = container.decoration! as BoxDecoration;
    expect(border.border!.top.color, AppColors.accent);
    expect(border.border!.top.width, 3);
  });
}
```

- [x] Verify RED: run `flutter test test/widgets/game_cover_card_test.dart` — expected: **assertion failures** (the badge and border are not yet rendered because the RED stub ignores `selectable`/`selected`).
- [x] **GATE — DO NOT PROCEED to GREEN until RED is verified.**

##### GREEN phase (only after RED is verified)

- [x] Replace the `build()` body in `lib/widgets/game_cover_card.dart` with the full implementation. The complete `build()` method:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(
      collectionProvider.select((s) => s.contains(game.id)),
    );
    final platformKey =
        game.ownedPlatformName ??
        (game.platformNames.isNotEmpty ? game.platformNames.first : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: selectable
            ? onToggleSelection
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
                ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.accent : Colors.white.withValues(alpha: 0.05),
              width: selected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                _CoverLayer(game: game),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.92),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (game.rating != null)
                        _RatingPill(rating: game.rating!),
                      const Spacer(),
                      if (selectable)
                        _SelectionBadge(selected: selected)
                      else if (owned)
                        const _OwnedPill(),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _Info(
                    game: game,
                    subtitle: subtitle,
                    platformKey: platformKey,
                    owned: owned,
                    onAddPressed: onAddPressed,
                    dense: dense,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

- [x] Add the `_SelectionBadge` widget at the bottom of the file, after `_QuickAddButton`:

```dart
class _SelectionBadge extends StatelessWidget {
  final bool selected;
  const _SelectionBadge({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
      color: selected ? AppColors.accent : Colors.white.withValues(alpha: 0.7),
      size: 26,
    );
  }
}
```

- [x] Verify GREEN: run `flutter test test/widgets/game_cover_card_test.dart` — expected: PASS

##### Step 4 Verification Checklist

**Automated (agent runs before stopping):**
- [x] RED verified — `flutter test test/widgets/game_cover_card_test.dart` fails as expected
- [x] GREEN verified — `flutter test test/widgets/game_cover_card_test.dart` passes
- [x] `flutter analyze` — passes

**Human (verify in browser before committing):**
*(Deferred to Step 6 — selectable mode is not yet active in the Shelf)*

#### Step 4 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 5: l10n — add 5 keys to all 6 ARBs + regenerate localizations

*(Non-testable step — standard format, no RED/GREEN needed)*

- [x] Append the following keys to `lib/l10n/app_en.arb` (before the closing `}`):

```json
,
  "menuSelectGames": "Select games",
  "nSelected": "{count, plural, =1{1 selected} other{{count} selected}}",
  "@nSelected": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesTitle": "{count, plural, =1{Remove 1 game?} other{Remove {count} games?}}",
  "@removeNGamesTitle": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesMessage": "These games will be removed from your shelf.",
  "gamesRemoved": "{count, plural, =1{1 game removed} other{{count} games removed}}",
  "@gamesRemoved": {"placeholders": {"count": {"type": "int"}}}
```

- [x] Append the following keys to `lib/l10n/app_es.arb` (values-only, no `@` metadata):

```json
,
  "menuSelectGames": "Seleccionar juegos",
  "nSelected": "{count, plural, =1{1 seleccionado} other{{count} seleccionados}}",
  "removeNGamesTitle": "{count, plural, =1{¿Quitar 1 juego?} other{¿Quitar {count} juegos?}}",
  "removeNGamesMessage": "Estos juegos se quitarán de tu estantería.",
  "gamesRemoved": "{count, plural, =1{1 juego eliminado} other{{count} juegos eliminados}}"
```

- [x] Append the following keys to `lib/l10n/app_fr.arb` (values-only, no `@` metadata):

```json
,
  "menuSelectGames": "Sélectionner des jeux",
  "nSelected": "{count, plural, =1{1 sélectionné} other{{count} sélectionnés}}",
  "removeNGamesTitle": "{count, plural, =1{Retirer 1 jeu ?} other{Retirer {count} jeux ?}}",
  "removeNGamesMessage": "Ces jeux seront retirés de votre étagère.",
  "gamesRemoved": "{count, plural, =1{1 jeu retiré} other{{count} jeux retirés}}"
```

- [x] Append the following keys to `lib/l10n/app_pt.arb` (values + `@` metadata, matching existing convention):

```json
,
  "menuSelectGames": "Selecionar jogos",
  "nSelected": "{count, plural, =1{1 selecionado} other{{count} selecionados}}",
  "@nSelected": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesTitle": "{count, plural, =1{Remover 1 jogo?} other{Remover {count} jogos?}}",
  "@removeNGamesTitle": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesMessage": "Estes jogos serão removidos da sua prateleira.",
  "gamesRemoved": "{count, plural, =1{1 jogo removido} other{{count} jogos removidos}}",
  "@gamesRemoved": {"placeholders": {"count": {"type": "int"}}}
```

- [x] Append the following keys to `lib/l10n/app_pt_BR.arb` (values + `@` metadata):

```json
,
  "menuSelectGames": "Selecionar jogos",
  "nSelected": "{count, plural, =1{1 selecionado} other{{count} selecionados}}",
  "@nSelected": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesTitle": "{count, plural, =1{Remover 1 jogo?} other{Remover {count} jogos?}}",
  "@removeNGamesTitle": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesMessage": "Estes jogos serão removidos da sua prateleira.",
  "gamesRemoved": "{count, plural, =1{1 jogo removido} other{{count} jogos removidos}}",
  "@gamesRemoved": {"placeholders": {"count": {"type": "int"}}}
```

- [x] Append the following keys to `lib/l10n/app_pt_PT.arb` (values + `@` metadata):

```json
,
  "menuSelectGames": "Selecionar jogos",
  "nSelected": "{count, plural, =1{1 selecionado} other{{count} selecionados}}",
  "@nSelected": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesTitle": "{count, plural, =1{Remover 1 jogo?} other{Remover {count} jogos?}}",
  "@removeNGamesTitle": {"placeholders": {"count": {"type": "int"}}},
  "removeNGamesMessage": "Estes jogos serão removidos da tua estante.",
  "gamesRemoved": "{count, plural, =1{1 jogo removido} other{{count} jogos removidos}}",
  "@gamesRemoved": {"placeholders": {"count": {"type": "int"}}}
```

- [x] Run `flutter gen-l10n` from the project root.
- [x] Verify that `lib/l10n/app_localizations*.dart` were regenerated and now contain the five new members (`menuSelectGames`, `nSelected`, `removeNGamesTitle`, `removeNGamesMessage`, `gamesRemoved`).

##### Step 5 Verification Checklist

**Automated (agent runs before stopping):**
- [x] `flutter gen-l10n` — succeeds without errors
- [x] `flutter analyze` — passes (unused public getters are acceptable)

**Human (verify in browser before committing):**
*(No browser checks — strings are not yet referenced in the UI)*

#### Step 5 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No browser verification required at this step.

---

#### Step 6: HomeScreen _SummaryTab selection mode + inline bulk-remove flow

*(Integration step — first step where deferred UI components are rendered)*

- [ ] Convert `_SummaryTab` in `lib/screens/home_screen.dart` from `ConsumerWidget` to `ConsumerStatefulWidget`:

Replace:
```dart
class _SummaryTab extends ConsumerWidget {
  final VoidCallback onJumpToSearch;
  const _SummaryTab({required this.onJumpToSearch});
```

With:
```dart
class _SummaryTab extends ConsumerStatefulWidget {
  final VoidCallback onJumpToSearch;
  const _SummaryTab({required this.onJumpToSearch});

  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  bool _inSelectionMode = false;
  final Set<int> _selectedIds = {};

  void _enterSelectionMode() {
    setState(() {
      _inSelectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _inSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkRemove(BuildContext context) async {
    if (_selectedIds.isEmpty) return;
    final l10n = context.l10n;
    final n = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHi,
        title: Text(l10n.removeNGamesTitle(n)),
        content: Text(l10n.removeNGamesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.removeShort),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(collectionProvider.notifier);

    final snapshot = await notifier.removeMany(_selectedIds.toList());

    setState(() {
      _inSelectionMode = false;
      _selectedIds.clear();
    });

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        persist: false,
        content: Row(
          children: [
            const Icon(Icons.remove_circle, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.gamesRemoved(n),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.undo,
          textColor: AppColors.accent,
          onPressed: () => notifier.restoreMany(snapshot),
        ),
      ),
    );
  }
```

- [ ] Update the `build()` method of `_SummaryTabState`. Replace the `SliverAppBar` block with:

```dart
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              _inSelectionMode
                  ? l10n.nSelected(_selectedIds.length)
                  : l10n.shelfTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            actions: _inSelectionMode
                ? [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                      ),
                      tooltip: l10n.cancel,
                      onPressed: _exitSelectionMode,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_rounded,
                        color: AppColors.danger,
                      ),
                      tooltip: l10n.removeShort,
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _bulkRemove(context),
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(
                        Icons.checklist_rounded,
                        color: AppColors.textPrimary,
                      ),
                      tooltip: l10n.menuSelectGames,
                      onPressed: _enterSelectionMode,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.textPrimary,
                      ),
                      tooltip: l10n.sharedCollectionsTooltip,
                      onPressed: () {
                        ref.read(analyticsServiceProvider).logScreenView(
                          screenName: 'shared_collections',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SharedCollectionsScreen(),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textPrimary,
                      ),
                      onSelected: (v) => switch (v) {
                        'export' => _export(context, ref),
                        'import' => _import(context, ref),
                        _ => () {
                            final count = ref.read(collectionProvider).games.length;
                            ref.read(analyticsServiceProvider).logShareQrGenerated(
                              gameCount: count,
                            );
                            showShareQrSheet(context);
                          }(),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'share_qr',
                          child: ListTile(
                            leading: const Icon(Icons.qr_code_rounded),
                            title: Text(l10n.menuShareQr),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: ListTile(
                            leading: const Icon(Icons.upload_file),
                            title: Text(l10n.menuExport),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'import',
                          child: ListTile(
                            leading: const Icon(Icons.download),
                            title: Text(l10n.menuImport),
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
```

- [ ] In the `SliverChildBuilderDelegate` inside the `SliverGrid`, replace the `GameCoverCard` invocation with:

```dart
                  return GameCoverCard(
                        game: game,
                        dense: true,
                        selectable: _inSelectionMode,
                        selected: _selectedIds.contains(game.id),
                        onToggleSelection: () => _toggleSelection(game.id),
                        onAddPressed: _inSelectionMode
                            ? null
                            : () => _toggleOwnership(
                                  context,
                                  ref,
                                  game,
                                  !state.contains(game.id),
                                ),
                      )
```

- [ ] Ensure `_export`, `_import`, and `_toggleOwnership` are still present in `_SummaryTabState` (moved from the old `ConsumerWidget` body).

##### Step 6 Verification Checklist

**Automated (agent runs before stopping):**
- [ ] `flutter analyze` — passes
- [ ] `flutter test test/widgets/game_cover_card_test.dart` — passes (no regression)
- [ ] `flutter test test/providers/collection_provider_test.dart` — passes (no regression)
- [ ] `flutter test test/services/collection_repository_test.dart` — passes (no regression)

**Human (verify in browser before committing):**

*Deferred from Step 4 (GameCoverCard selection visuals):*
- [ ] Enter selection mode on the Shelf; tap a cover — it shows a filled checkmark badge and an accent border
- [ ] Tap the same cover again — the badge becomes an empty ring and the border disappears

*Step 6:*
- [ ] The Shelf app bar shows a checklist icon; tapping it enters selection mode and clears any prior selection
- [ ] In selection mode the app bar title shows "{N} selected"; actions are Close and Delete (disabled at 0)
- [ ] The overflow menu (Share / Export / Import) is hidden in selection mode
- [ ] Tapping a cover in selection mode toggles selection; it does NOT open the detail screen
- [ ] The per-card quick-add/remove button is hidden in selection mode
- [ ] Tap Delete with N selected → confirmation dialog shows "Remove N games?" and "These games will be removed from your shelf."
- [ ] Confirming removes all N games and exits selection mode; a snackbar appears with "N games removed" and an Undo action
- [ ] Tapping Undo restores all N games with their original owned platform and `addedAt`
- [ ] Cancelling the dialog leaves the selection intact
- [ ] Tapping Close exits selection mode and clears the selection

#### Step 6 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Wait for the human to verify all Human checks above (including all deferred ones) in the browser, then stage and commit before continuing.

---

#### Step 7: End-to-end bulk-remove widget test

*(Testable step — use RED → GREEN)*

##### RED phase

- [ ] Write the minimal failing test into `test/widgets/bulk_remove_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/providers/collection_provider.dart';
import 'package:vgcollection/screens/home_screen.dart';

class _StubCollection extends CollectionNotifier {
  _StubCollection(this._games);

  final List<Game> _games;
  final List<List<int>> removedMany = [];
  final List<List<Game>> restoredMany = [];

  @override
  CollectionState build() => CollectionState(games: _games, loaded: true);

  @override
  Future<List<Game>> removeMany(List<int> ids) async {
    removedMany.add(ids);
    final removed = _games.where((g) => ids.contains(g.id)).toList();
    state = state.copyWith(
      games: [
        for (final g in state.games)
          if (!ids.contains(g.id)) g,
      ],
    );
    return removed;
  }

  @override
  Future<void> restoreMany(List<Game> snapshot) async {
    restoredMany.add(snapshot);
    state = state.copyWith(games: [...state.games, ...snapshot]);
  }
}

Future<_StubCollection> _pumpHome(WidgetTester tester, List<Game> games) async {
  final stub = _StubCollection(games);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionProvider.overrideWith(() => stub),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return stub;
}

void main() {
  final games = [
    Game(id: 1, name: 'Chrono Trigger', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 1, 1)),
    Game(id: 2, name: 'Final Fantasy VI', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 2, 1)),
    Game(id: 3, name: 'Super Mario World', ownedPlatformName: 'SNES', addedAt: DateTime(2024, 3, 1)),
  ];

  testWidgets('full bulk-remove + undo flow round-trips the Shelf', (tester) async {
    final stub = await _pumpHome(tester, games);

    // Enter selection mode
    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();

    // Select two games
    await tester.tap(find.text('Chrono Trigger'));
    await tester.pump();
    await tester.tap(find.text('Final Fantasy VI'));
    await tester.pump();

    // Tap Delete
    await tester.tap(find.byIcon(Icons.delete_rounded));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Remove 2 games?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Assert removed
    expect(find.text('Chrono Trigger'), findsNothing);
    expect(find.text('Final Fantasy VI'), findsNothing);
    expect(find.text('Super Mario World'), findsOneWidget);

    // Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Assert restored
    expect(find.text('Chrono Trigger'), findsOneWidget);
    expect(find.text('Final Fantasy VI'), findsOneWidget);
    expect(find.text('Super Mario World'), findsOneWidget);

    // Verify stub calls
    expect(stub.removedMany, hasLength(1));
    expect(stub.removedMany.single, containsAll([1, 2]));
    expect(stub.restoredMany, hasLength(1));
    expect(stub.restoredMany.single, hasLength(2));
  });
}
```

- [ ] Verify RED: run `flutter test test/widgets/bulk_remove_flow_test.dart` — expected: **assertion failures** (the checklist icon or the selection flow is not yet fully wired, causing the test to fail on missing widgets or incorrect state).
- [ ] **GATE — DO NOT PROCEED to GREEN until RED is verified.**

##### GREEN phase (only after RED is verified)

- [ ] Since Step 6 already implemented the full production code, the GREEN phase for this step is to ensure the test passes as-is. If the RED test failed for unexpected reasons (e.g., finder issues), adjust the test helpers only — do **not** modify production code.
- [ ] Verify GREEN: run `flutter test test/widgets/bulk_remove_flow_test.dart` — expected: PASS

##### Step 7 Verification Checklist

**Automated (agent runs before stopping):**
- [ ] RED verified — `flutter test test/widgets/bulk_remove_flow_test.dart` fails as expected
- [ ] GREEN verified — `flutter test test/widgets/bulk_remove_flow_test.dart` passes
- [ ] `flutter test` — all tests in the project pass (no regressions)
- [ ] `flutter analyze` — passes

**Human (verify in browser before committing):**
*(All deferred checks were already verified in Step 6)*

#### Step 7 STOP & COMMIT

**sai-4-apply:** Run all Automated checks above and confirm they pass before stopping.

**STOP & COMMIT:** Stage and commit after Automated checks pass. No additional browser verification required at this step.

## Appendix: Plan vs Final Implementation

This section documents deviations between the original plan and the code that was actually merged.

### Step 1 — sqflite_common_ffi version downgraded

**Plan:** Add `sqflite_common_ffi: ^2.5.0` to `dev_dependencies:`.
**Final:** Added `sqflite_common_ffi: ^2.4.2+1` (via `flutter pub add`).
**Reason:** `^2.5.0` failed to resolve against the SDK/dependency set this project pins; the resolver recommended downgrading to `^2.4.2+1`, which exposes the same `databaseFactory`/`sqfliteFfiInit` surface used by the tests.

### Step 1 — test-only opener seam lints

**Plan:** Stub constructor `CollectionRepository({Future<Database> Function()? opener}) : _opener = opener;` with a private `_opener` field.
**Final:** Field renamed to `_customOpener` (parameter stays `opener`), and the `!` in `_opener!()` removed via a promoted local.
**Reason:** `flutter analyze` flagged `prefer_initializing_formals` on `_opener = opener` (the analyzer normalizes leading underscores, treating `opener`/`_opener` as a match) and `unnecessary_non_null_assertion` on `_opener!()`. Since private named parameters are invalid Dart, the suggested `this._opener` fix could not be applied; renaming the field and dropping the redundant `!` keeps the plan's public `opener:` call site intact.

### Step 1 — test file lints

**Plan:** Test imports both `sqflite` and `sqflite_common_ffi` and names the in-memory opener `_openInMemory`.
**Final:** Removed the `package:sqflite/sqflite.dart` import and renamed `_openInMemory` to `openInMemory`.
**Reason:** `flutter analyze` reported `unnecessary_import` (all used symbols come from `sqflite_common_ffi`) and `no_leading_underscores_for_local_identifiers`.

### Step 3 — notifier test fixture missing `setCrashlyticsKey`

**Plan:** `_FakeAnalytics` in `test/providers/collection_provider_test.dart` implements only `logBulkGamesRemoved` plus `noSuchMethod`, and nothing else.
**Final:** Added an explicit no-op override `void setCrashlyticsKey(String key, Object value) {}` to `_FakeAnalytics`.
**Reason:** `CollectionNotifier.build()` and `_load()` call `_analytics.setCrashlyticsKey('collection_size', len)`, which routed to `Object.noSuchMethod` and threw `NoSuchMethodError`, failing every test before assertions ran.

### Step 4 — widget test needs a stubbed collection provider

**Plan:** `test/widgets/game_cover_card_test.dart` pumps `GameCoverCard` inside a bare `ProviderScope` with no overrides.
**Final:** The `ProviderScope` overrides `collectionProvider` with a `_StubCollection extends CollectionNotifier` whose `build()` returns `const CollectionState(loaded: true)`; the local helper was also renamed `_pumpCard` → `pumpCard`.
**Reason:** The real notifier's `build()` reads the throwing default `analyticsServiceProvider`/`reviewServiceProvider` (and its `_load()` hits sqflite), so pumping the card raised a Riverpod `ProviderException` in addition to the assertion failure. Stubbing the provider is the established pattern in this repo (`test/widgets/remove_game_flow_test.dart`). The renamed helper avoids `no_leading_underscores_for_local_identifiers`.
