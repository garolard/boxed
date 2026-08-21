import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/models/game.dart';
import 'package:vgcollection/providers/collection_provider.dart';
import 'package:vgcollection/widgets/game_cover_card.dart';
import 'package:vgcollection/theme/app_theme.dart';

/// Stands in for the real notifier, whose `build()` hits sqflite and the
/// throwing analytics/review providers.
class _StubCollection extends CollectionNotifier {
  @override
  CollectionState build() => const CollectionState(loaded: true);
}

void main() {
  Widget pumpCard(WidgetTester tester, {
    required bool selectable,
    required bool selected,
  }) {
    return ProviderScope(
      overrides: [
        collectionProvider.overrideWith(() => _StubCollection()),
      ],
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
    await tester.pumpWidget(pumpCard(tester, selectable: true, selected: false));
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
    await tester.pumpWidget(pumpCard(tester, selectable: true, selected: true));
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