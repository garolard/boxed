import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/l10n/app_localizations.dart';
import 'package:vgcollection/providers/services.dart';
import 'package:vgcollection/screens/paywall_screen.dart';
import 'package:vgcollection/services/purchase/purchase_service.dart';

import '../services/purchase/fake_purchase_service.dart';

void main() {
  testWidgets('price renders in the CTA', (tester) async {
    final fake = FakePurchaseService();
    fake.product = const PurchaseProduct(id: 'premium', priceString: r'$4.99');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PaywallScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining(r'$4.99'), findsOneWidget);
  });

  testWidgets('CTA success dismisses the paywall', (tester) async {
    final fake = FakePurchaseService();
    fake.product = const PurchaseProduct(id: 'premium', priceString: r'$4.99');
    fake.purchaseOutcome = const PurchaseSuccess();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const PaywallScreen(),
                    ));
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          }),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
  });

  testWidgets('Restore is wired', (tester) async {
    final fake = FakePurchaseService();
    fake.restoreOutcome = const PurchaseError('No purchases to restore');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PaywallScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(fake.restoreCallCount, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('cancel leaves paywall open with no error', (tester) async {
    final fake = FakePurchaseService();
    fake.product = const PurchaseProduct(id: 'premium', priceString: r'$4.99');
    fake.purchaseOutcome = const PurchaseCancelled();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PaywallScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
