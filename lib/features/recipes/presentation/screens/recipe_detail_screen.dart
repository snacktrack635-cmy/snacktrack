import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/data/models/shopping_list_item.dart';
import 'package:snacktrack/features/recipes/application/favorites_controller.dart';
import 'package:snacktrack/features/recipes/application/recipe_generation_controller.dart';
import 'package:snacktrack/features/shopping_list/application/shopping_list_controller.dart';
import 'package:snacktrack/widgets/app_button.dart';
import 'package:snacktrack/widgets/could_not_find_recipe_view.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final Recipe? initialRecipe;
  final String? fallbackIngredientName;

  const RecipeDetailScreen({
    super.key,
    this.initialRecipe,
    this.fallbackIngredientName,
  });

  bool _isCouldNotFindRecipe(Recipe? recipe) {
    if (recipe == null) return true;
    final name = recipe.name.trim().toLowerCase();
    if (name.isEmpty || name == 'untitled recipe' || name == 'untitled') {
      return true;
    }
    if (recipe.ingredients.isEmpty && recipe.instructions.isEmpty) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genState = ref.watch(recipeGenerationControllerProvider);
    final favState = ref.watch(favoritesControllerProvider);

    final recipe = initialRecipe ?? genState.currentRecipe;

    if (genState.isGenerating && recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generating Recipe...')),
        body: const LoadingView(
          message: 'Gemini AI is crafting your recipe based on your pantry...',
        ),
      );
    }

    if (genState.errorMessage != null && recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe Generation')),
        body: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorView(
                message: genState.errorMessage!,
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
        ),
      );
    }

    if (recipe == null || _isCouldNotFindRecipe(recipe)) {
      final ingredient = recipe?.primaryIngredient ?? fallbackIngredientName;
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe Details')),
        body: CouldNotFindRecipeView(
          ingredientName: ingredient,
          onRetry: ingredient != null && ingredient.isNotEmpty
              ? () {
                  ref
                      .read(recipeGenerationControllerProvider.notifier)
                      .generateRecipeForItem(ingredient);
                }
              : null,
          onBackToPantry: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/pantry');
            }
          },
        ),
      );
    }

    final isFav = favState.favorites.any(
      (f) => f.recipeId == recipe.id || f.recipeSnapshot.name == recipe.name,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? AppColors.error : null,
            ),
            tooltip: isFav ? 'Remove from Saved Recipes' : 'Save to Favorites',
            onPressed: () {
              final wasFav = isFav;
              ref.read(favoritesControllerProvider.notifier).toggleFavorite(recipe);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    wasFav
                        ? 'Removed "${recipe.name}" from Saved Recipes'
                        : 'Saved "${recipe.name}" to Favorites!',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Header Banner
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: AppSpacing.borderRadiusLg,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.secondaryDark,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (recipe.primaryIngredient != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Featured Ingredient: ${recipe.primaryIngredient}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Ingredients Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ingredients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('Add to Shopping List'),
                  onPressed: () {
                    for (final ing in recipe.ingredients) {
                      ref.read(shoppingListControllerProvider.notifier).addItem(
                            ShoppingListItem(
                              id: '',
                              userId: '',
                              name: ing.name,
                              source: 'recipe',
                              createdAt: DateTime.now(),
                            ),
                          );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ingredients added to your shopping list!'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recipe.ingredients.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ingredient = recipe.ingredients[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.circle,
                      size: 8,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      ingredient.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    trailing: ingredient.quantity != null
                        ? Text(
                            ingredient.quantity!,
                            style: const TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Instructions Section
            const Text(
              'Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: AppSpacing.paddingMd,
                itemCount: recipe.instructions.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final step = recipe.instructions[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
