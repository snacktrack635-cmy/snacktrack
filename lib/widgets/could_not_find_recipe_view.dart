import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import 'app_button.dart';

class CouldNotFindRecipeView extends StatelessWidget {
  final String? ingredientName;
  final VoidCallback? onRetry;
  final VoidCallback? onBackToPantry;

  const CouldNotFindRecipeView({
    super.key,
    this.ingredientName,
    this.onRetry,
    this.onBackToPantry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: AppColors.secondaryDark,
                size: 56,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Could Not Find Recipe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ingredientName != null && ingredientName!.isNotEmpty
                  ? 'We could not find or generate a recipe for "$ingredientName". Please try again or select another ingredient from your pantry.'
                  : 'We could not find or generate a recipe with the selected pantry item. Please try again or choose another item.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (onRetry != null)
              AppButton(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            if (onRetry != null && onBackToPantry != null)
              const SizedBox(height: AppSpacing.sm),
            if (onBackToPantry != null)
              AppButton(
                label: 'Back to Pantry',
                icon: Icons.kitchen_rounded,
                variant: AppButtonVariant.outlined,
                onPressed: onBackToPantry,
              ),
          ],
        ),
      ),
    );
  }
}
