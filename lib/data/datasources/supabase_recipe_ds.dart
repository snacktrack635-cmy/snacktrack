import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/supabase_client.dart';
import '../models/recipe.dart';

class SupabaseRecipeDataSource {
  final SupabaseClient _client;

  SupabaseRecipeDataSource(this._client);

  Future<Recipe?> getCachedRecipe({
    required String normalizedName,
    String? primaryIngredient,
  }) async {
    try {
      var query = _client
          .from(AppConstants.recipesTable)
          .select()
          .eq('normalized_name', normalizedName);

      if (primaryIngredient != null && primaryIngredient.isNotEmpty) {
        query = query.eq('primary_ingredient', primaryIngredient);
      }

      final response = await query.order('generation_count', ascending: false).limit(1).maybeSingle();
      if (response == null) return null;
      return Recipe.fromJson(response);
    } catch (e, st) {
      AppSupabaseClient.logError('getCachedRecipe ("$normalizedName")', e, st);
      return null;
    }
  }

  Future<List<FavoriteRecipe>> getFavorites() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from(AppConstants.favoriteRecipesTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => FavoriteRecipe.fromJson(json)).toList();
    } catch (e, st) {
      AppSupabaseClient.logError('getFavorites', e, st);
      rethrow;
    }
  }

  Future<FavoriteRecipe> addFavorite({
    required String recipeId,
    required Recipe recipe,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final data = {
      'user_id': userId,
      'recipe_id': recipeId,
      'recipe_snapshot': recipe.toJson(),
    };

    try {
      final response = await _client
          .from(AppConstants.favoriteRecipesTable)
          .upsert(data)
          .select()
          .single();

      return FavoriteRecipe.fromJson(response);
    } catch (e, st) {
      AppSupabaseClient.logError('addFavorite ("$recipeId")', e, st);
      rethrow;
    }
  }

  Future<void> removeFavorite(String recipeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from(AppConstants.favoriteRecipesTable)
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
    } catch (e, st) {
      AppSupabaseClient.logError('removeFavorite ("$recipeId")', e, st);
      rethrow;
    }
  }

  Future<bool> isFavorited(String recipeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _client
          .from(AppConstants.favoriteRecipesTable)
          .select('id')
          .eq('user_id', userId)
          .eq('recipe_id', recipeId)
          .maybeSingle();

      return response != null;
    } catch (e, st) {
      AppSupabaseClient.logError('isFavorited ("$recipeId")', e, st);
      return false;
    }
  }
}
