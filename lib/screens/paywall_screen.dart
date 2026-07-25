import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/services.dart';
import '../services/purchase/purchase_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  late final Future<PurchaseProduct?> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = ref.read(purchaseServiceProvider).premiumProduct();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.paywallTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.paywallSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _FeatureRow(icon: Icons.check_circle_outline, text: l10n.paywallFeature1),
              const SizedBox(height: 12),
              _FeatureRow(icon: Icons.check_circle_outline, text: l10n.paywallFeature2),
              const SizedBox(height: 12),
              _FeatureRow(icon: Icons.check_circle_outline, text: l10n.paywallFeature3),
              const Spacer(),
              FilledButton(
                onPressed: () => _handlePurchase(context),
                child: FutureBuilder<PurchaseProduct?>(
                  future: _productFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    final product = snapshot.data;
                    if (product != null) {
                      return Text(l10n.paywallCtaPrice(product.priceString));
                    }
                    return Text(l10n.paywallCtaFallback);
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _handleRestore(context),
                child: Text(l10n.paywallRestore),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase(BuildContext context) async {
    final outcome = await ref.read(purchaseServiceProvider).purchasePremium();
    if (!context.mounted) return;
    switch (outcome) {
      case PurchaseSuccess():
        Navigator.of(context).pop();
      case PurchaseCancelled():
        break;
      case PurchaseError():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paywallPurchaseError)),
        );
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final outcome = await ref.read(purchaseServiceProvider).restore();
    if (!context.mounted) return;
    switch (outcome) {
      case PurchaseSuccess():
        Navigator.of(context).pop();
      case PurchaseError(:final message):
        final l10n = context.l10n;
        final text = message.toLowerCase().contains('no purchases') ||
                message.toLowerCase().contains('nothing')
            ? l10n.paywallNothingToRestore
            : l10n.paywallRestoreError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      case PurchaseCancelled():
        break;
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
