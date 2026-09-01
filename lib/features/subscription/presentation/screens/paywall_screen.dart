import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/core/constants/tier_limits.dart';
import 'package:snacktrack/features/subscription/application/subscription_controller.dart';
import 'package:snacktrack/widgets/app_button.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  SubscriptionTier _selectedTier = SubscriptionTier.plus;

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade SnackTrack'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/pantry');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 48,
                  color: AppColors.secondaryDark,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Unlock Full Pantry Superpowers',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Enjoy unlimited AI recipes, batch barcode scanning, and smart expiry tracking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Tier Cards
            _buildTierCard(
              tier: SubscriptionTier.free,
              title: 'Free Tier',
              price: '\$0 / month',
              features: const [
                '3 barcode scans per month',
                'Single-item scan mode',
                '5 Gemini AI recipe generations / mo',
                'Basic pantry & shopping list',
              ],
              isCurrent: subState.currentTier == SubscriptionTier.free,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTierCard(
              tier: SubscriptionTier.plus,
              title: 'Plus Tier',
              price: '\$4.99 / month',
              badge: 'POPULAR',
              features: const [
                '50 scans per month',
                '⚡ Fast batch scanning unlocked',
                '30 Gemini AI recipe generations / mo',
                'Zero-waste expiring soon recommendations',
                'Export shopping lists to CSV / Share',
              ],
              isCurrent: subState.currentTier == SubscriptionTier.plus,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTierCard(
              tier: SubscriptionTier.pro,
              title: 'Pro Tier',
              price: '\$9.99 / month',
              badge: 'UNLIMITED',
              features: const [
                '🚀 Unlimited barcode & label scans',
                '⚡ Fast batch scanning',
                '🚀 Unlimited Gemini AI recipe generations',
                'Priority recipe cache & AI generation',
                'All future premium features included',
              ],
              isCurrent: subState.currentTier == SubscriptionTier.pro,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Subscribe CTA
            AppButton(
              label: subState.isUpgrading
                  ? 'Processing...'
                  : 'Subscribe to ${_selectedTier.name.toUpperCase()}',
              isLoading: subState.isUpgrading,
              icon: Icons.lock_open_rounded,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                final tierName = _selectedTier.name.toUpperCase();

                await ref
                    .read(subscriptionControllerProvider.notifier)
                    .upgradeToTier(_selectedTier);

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Subscribed to $tierName!'),
                  ),
                );

                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go('/pantry');
                }
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Continue with Free
            TextButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/pantry');
                }
              },
              child: const Text('Continue with Free Tier'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required SubscriptionTier tier,
    required String title,
    required String price,
    String? badge,
    required List<String> features,
    required bool isCurrent,
  }) {
    final isSelected = _selectedTier == tier;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTier = tier;
        });
      },
      borderRadius: AppSpacing.borderRadiusLg,
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
