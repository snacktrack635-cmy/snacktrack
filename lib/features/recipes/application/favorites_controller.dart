import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/recipe.dart';
import '../../../data/repositories/recipe_repository.dart';
import '../../../providers/global_providers.dart';

class FavoritesState {
  final List<FavoriteRecipe> favorites;
  final bool isLoading;
  final String? errorMessage;

  const FavoritesState({
    this.favorites = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  FavoritesState copyWith({
    List<FavoriteRecipe>? favorites,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class FavoritesController extends StateNotifier<FavoritesState> {
  final RecipeRepository _recipeRepository;

  FavoritesController(this._recipeRepository) : super(const FavoritesState()) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final favorites = await _recipeRepository.getFavorites();
      state = state.copyWith(favorites: favorites, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load favorites: $e',
      );
    }
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    final isAlreadyFav = state.favorites.any((f) => f.recipeId == recipe.id || f.recipeSnapshot.name == recipe.name);

    if (isAlreadyFav) {
      final existingFav = state.favorites.firstWhere(
        (f) => f.recipeId == recipe.id || f.recipeSnapshot.name == recipe.name,
      );
      try {
        final targetRecipeId = existingFav.recipeId.isNotEmpty ? existingFav.recipeId : recipe.id;
        await _recipeRepository.removeFavorite(targetRecipeId);
        state = state.copyWith(
          favorites: state.favorites
              .where((f) => f.recipeId != existingFav.recipeId && f.recipeSnapshot.name != recipe.name)
              .toList(),
        );
      } catch (e) {
        state = state.copyWith(errorMessage: 'Failed to remove favorite: $e');
      }
    } else {
      try {
        final newFav = await _recipeRepository.addFavorite(recipe);
        state = state.copyWith(favorites: [newFav, ...state.favorites]);
      } catch (e) {
        state = state.copyWith(errorMessage: 'Failed to add favorite: $e');
      }
    }
  }

  bool isFavorite(String? recipeId, String? recipeName) {
    return state.favorites.any(
      (f) => (recipeId != null && f.recipeId == recipeId) || (recipeName != null && f.recipeSnapshot.name == recipeName),
    );
  }
}

final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, FavoritesState>((ref) {
  final repository = ref.watch(recipeRepositoryProvider);
  return FavoritesController(repository);
});
