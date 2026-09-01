import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/features/recipes/application/recipe_generation_controller.dart';
import 'package:snacktrack/widgets/app_button.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';

class ExpiringSoonRecipesScreen extends ConsumerStatefulWidget {
  const ExpiringSoonRecipesScreen({super.key});

  @override
  ConsumerState<ExpiringSoonRecipesScreen> createState() =>
      _ExpiringSoonRecipesScreenState();
}

class _ExpiringSoonRecipesScreenState
    extends ConsumerState<ExpiringSoonRecipesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recipeGenerationControllerProvider.notifier)
          .generateExpiringSoonRecipe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(recipeGenerationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Soon Recipe'),
      ),
      body: Builder(
        builder: (context) {
          if (genState.isGenerating) {
            return const LoadingView(
              message:
                  'Finding expiring ingredients & generating a zero-waste recipe...',
            );
          }

          if (genState.errorMessage != null) {
            return Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ErrorView(
                    message: genState.errorMessage!,
                    onRetry: () => ref
                        .read(recipeGenerationControllerProvider.notifier)
                        .generateExpiringSoonRecipe(),
                  ),
                  if (genState.isQuotaExceeded) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Upgrade Subscription',
                      icon: Icons.star_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.push('/subscription/paywall'),
                    ),
                  ],
                ],
              ),
            );
          }

          final recipe = genState.currentRecipe;
          if (recipe == null) {
            return const Center(child: Text('No recipe generated.'));
          }

          return SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zero-waste highlight banner
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: AppColors.expiryWarning.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusMd,
                    border: Border.all(
                      color: AppColors.expiryWarning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.eco_rounded,
                        color: AppColors.secondaryDark,
                        size: 28,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zero-Waste Recommendation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'This recipe was tailored to use pantry items nearing their expiry date.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // View recipe details button
                AppButton(
                  label: 'View Full Cooking Steps',
                  icon: Icons.restaurant_rounded,
                  width: double.infinity,
                  onPressed: () {
                    context.push('/recipes/detail', extra: recipe);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
