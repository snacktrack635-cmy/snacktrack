import '../datasources/edge_functions_ds.dart';
import '../datasources/supabase_recipe_ds.dart';
import '../models/recipe.dart';

class RecipeRepository {
  final SupabaseRecipeDataSource _recipeDataSource;
  final EdgeFunctionsDataSource _edgeFunctionsDataSource;

  RecipeRepository({
    required SupabaseRecipeDataSource recipeDataSource,
    required EdgeFunctionsDataSource edgeFunctionsDataSource,
  })  : _recipeDataSource = recipeDataSource,
        _edgeFunctionsDataSource = edgeFunctionsDataSource;

  Future<Recipe> generateRecipe({
    required String primaryIngredient,
    List<String> availablePantryItems = const [],
    String? pantryItemId,
  }) async {
    // 1. Try cache lookup first (indexed, normalized-name lookup: ~50-100ms)
    final normalized = primaryIngredient.trim().toLowerCase();
    final cached = await _recipeDataSource.getCachedRecipe(
      normalizedName: normalized,
      primaryIngredient: primaryIngredient,
    );

    if (cached != null) {
      return cached;
    }

    // 2. Cache miss -> invoke Edge Function (runs Gemini recipe name generation,
    // database check, creates full recipe and populates table if not found)
    return await _edgeFunctionsDataSource.generateRecipe(
      primaryIngredient: primaryIngredient,
      availablePantryItems: availablePantryItems,
      pantryItemId: pantryItemId,
    );
  }

  Future<Recipe> generateExpiringSoonRecipe({
    required List<String> expiringItems,
  }) async {
    return await _edgeFunctionsDataSource.generateExpiringSoonRecipe(
      expiringItems: expiringItems,
    );
  }

  Future<List<FavoriteRecipe>> getFavorites() async {
    return await _recipeDataSource.getFavorites();
  }

  Future<FavoriteRecipe> addFavorite(Recipe recipe) async {
    return await _recipeDataSource.addFavorite(
      recipeId: recipe.id,
      recipe: recipe,
    );
  }

  Future<void> removeFavorite(String recipeId) async {
    await _recipeDataSource.removeFavorite(recipeId);
  }

  Future<bool> isFavorited(String recipeId) async {
    return await _recipeDataSource.isFavorited(recipeId);
  }
}
