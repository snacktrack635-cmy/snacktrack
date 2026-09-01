import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/features/recipes/application/favorites_controller.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
      ),
      body: Builder(
        builder: (context) {
          if (favoritesState.isLoading && favoritesState.favorites.isEmpty) {
            return const LoadingView(message: 'Loading your saved recipes...');
          }

          if (favoritesState.errorMessage != null && favoritesState.favorites.isEmpty) {
            return ErrorView(
              message: favoritesState.errorMessage!,
              onRetry: () => ref.read(favoritesControllerProvider.notifier).loadFavorites(),
            );
          }

          if (favoritesState.favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.paddingXl,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'No saved recipes yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Generate recipes from your pantry items and tap the heart icon to save them here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: favoritesState.favorites.length,
            itemBuilder: (context, index) {
              final favorite = favoritesState.favorites[index];
              final recipe = favorite.recipeSnapshot;

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  contentPadding: AppSpacing.paddingMd,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                  title: Text(
                    recipe.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${recipe.ingredients.length} ingredients • ${recipe.instructions.length} steps',
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: AppColors.error),
                    onPressed: () {
                      ref.read(favoritesControllerProvider.notifier).toggleFavorite(recipe);
                    },
                  ),
                  onTap: () {
                    context.push('/recipes/detail', extra: recipe);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
