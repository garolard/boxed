import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/providers/collection_provider.dart';
import 'package:vgcollection/widgets/share_qr_sheet.dart';

/// Stands in for the real notifier, whose `build()` hits sqflite.
class _StubCollection extends CollectionNotifier {
  _StubCollection(this._games);

  final List<Game> _games;

  @override
  CollectionState build() => CollectionState(games: _games, loaded: true);
}

Game _game(int id) => Game(
      id: id,
      name: 'Game $id',
      ownedPlatformId: 18,
      ownedPlatformName: 'NES',
    );

Future<void> _openSheet(WidgetTester tester, {List<Game> games = const []}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionProvider.overrideWith(() => _StubCollection(games)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showShareQrSheet(context),
                child: const Text('share'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('share'));
  await tester.pumpAndSettle();
}

void main() {
  // Regression: the default shelf name was seeded in initState, which reads
  // Localizations and therefore registered an inherited-widget dependency
  // before initState had returned.
  testWidgets('opens without touching Localizations during initState',
      (tester) async {
    await _openSheet(tester, games: [_game(1), _game(2)]);

    expect(tester.takeException(), isNull);
  });

  testWidgets('seeds the localized default shelf name', (tester) async {
    await _openSheet(tester, games: [_game(1)]);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isNotEmpty);
  });

  testWidgets('a typed name survives a dependency change', (tester) async {
    await _openSheet(tester, games: [_game(1)]);

    await tester.enterText(find.byType(TextField), 'My shelf');
    await tester.pumpAndSettle();

    // Force didChangeDependencies to run again — it must not re-seed.
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'My shelf');
  });
}
