import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/providers/collection_provider.dart';
import 'package:vgcollection/widgets/remove_game_flow.dart';

/// Stands in for the real notifier, whose `build()` hits sqflite.
class _StubCollection extends CollectionNotifier {
  _StubCollection(this._games);

  final List<Game> _games;
  final List<int> removed = [];
  final List<Game> restored = [];

  @override
  CollectionState build() => CollectionState(games: _games, loaded: true);

  @override
  Future<void> remove(int gameId) async {
    removed.add(gameId);
    state = state.copyWith(
      games: [
        for (final g in state.games)
          if (g.id != gameId) g,
      ],
    );
  }

  @override
  Future<void> restore(Game entry) async {
    restored.add(entry);
    state = state.copyWith(games: [...state.games, entry]);
  }
}

final _stored = Game(
  id: 1,
  name: 'Chrono Trigger',
  ownedPlatformId: 19,
  ownedPlatformName: 'SNES',
  addedAt: DateTime(2024, 1, 1),
);

/// What a search result looks like: same id, none of the owned fields.
const _fromSearch = Game(id: 1, name: 'Chrono Trigger');

Future<_StubCollection> _pumpFlow(WidgetTester tester) async {
  final stub = _StubCollection([_stored]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [collectionProvider.overrideWith(() => stub)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => removeGameFlow(context, ref, _fromSearch),
                child: const Text('remove'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('remove'));
  await tester.pumpAndSettle();
  return stub;
}

void main() {
  testWidgets('cancelling the dialog removes nothing', (tester) async {
    final stub = await _pumpFlow(tester);
    expect(find.text('Remove game?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(stub.removed, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('confirming removes and shows an undo snackbar', (tester) async {
    final stub = await _pumpFlow(tester);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(stub.removed, [1]);
    expect(find.text('"Chrono Trigger" removed'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  // The button may be tapped from a search result that carries no owned
  // platform, so the flow has to restore the snapshot held in the collection.
  testWidgets('undo restores the stored entry, not the passed-in game',
      (tester) async {
    final stub = await _pumpFlow(tester);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(stub.restored, hasLength(1));
    expect(stub.restored.single.ownedPlatformName, 'SNES');
    expect(stub.restored.single.addedAt, DateTime(2024, 1, 1));
  });

  // The undo window is the snackbar's lifetime: it must close on its own.
  testWidgets('the snackbar dismisses itself and the undo goes with it',
      (tester) async {
    final stub = await _pumpFlow(tester);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 5),
    );

    // Stepped pumps: the dismissal timer is only armed on a frame after the
    // entrance animation completes, so one large pump would skip past it.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(SnackBar), findsNothing);
    expect(stub.restored, isEmpty);
  });
}
