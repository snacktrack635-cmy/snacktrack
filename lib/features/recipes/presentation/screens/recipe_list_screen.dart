import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/core/constants/app_colors.dart';
import 'package:snacktrack/core/constants/app_spacing.dart';
import 'package:snacktrack/features/recipes/application/favorites_controller.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';
import '../widgets/recipe_card.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(favoritesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(favoritesControllerProvider.notifier).loadFavorites(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(favoritesControllerProvider.notifier).loadFavorites(),
        child: Builder(
          builder: (context) {
            if (favoritesState.isLoading && favoritesState.favorites.isEmpty) {
              return const LoadingView(message: 'Loading your saved recipes...');
            }

            if (favoritesState.errorMessage != null && favoritesState.favorites.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: ErrorView(
                      message: favoritesState.errorMessage!,
                      onRetry: () => ref.read(favoritesControllerProvider.notifier).loadFavorites(),
                    ),
                  ),
                ],
              );
            }

            if (favoritesState.favorites.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(
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
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.paddingMd,
              itemCount: favoritesState.favorites.length,
              itemBuilder: (context, index) {
                final favorite = favoritesState.favorites[index];
                final recipe = favorite.recipeSnapshot;

                return RecipeCard(
                  recipe: recipe,
                  isFavorite: true,
                  onTap: () {
                    context.push('/recipes/detail', extra: recipe);
                  },
                  onToggleFavorite: () {
                    ref.read(favoritesControllerProvider.notifier).toggleFavorite(recipe);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
