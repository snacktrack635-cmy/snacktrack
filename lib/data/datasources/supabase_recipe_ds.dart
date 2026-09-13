import 'package:flutter/foundation.dart';
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
    var userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await AppSupabaseClient.ensureAuthenticated();
      userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ [SupabaseRecipeDataSource.getFavorites] No authenticated user session found.');
        return [];
      }
    }

    try {
      debugPrint('🔍 [SupabaseRecipeDataSource.getFavorites] Fetching favorites from "${AppConstants.favoriteRecipesTable}" for user: $userId');
      final response = await _client
          .from(AppConstants.favoriteRecipesTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (response as List).map((json) => FavoriteRecipe.fromJson(json)).toList();
      debugPrint('✅ [SupabaseRecipeDataSource.getFavorites] Retrieved ${list.length} saved recipes for user: $userId');
      return list;
    } catch (e, st) {
      AppSupabaseClient.logError('getFavorites', e, st);
      rethrow;
    }
  }

  Future<FavoriteRecipe> addFavorite({
    required String recipeId,
    required Recipe recipe,
  }) async {
    var userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await AppSupabaseClient.ensureAuthenticated();
      userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');
    }

    final effectiveRecipeId = recipeId.isNotEmpty ? recipeId : recipe.id;

    final data = {
      'user_id': userId,
      'recipe_id': effectiveRecipeId,
      'recipe_snapshot': recipe.toJson(),
    };

    try {
      debugPrint('💖 [SupabaseRecipeDataSource.addFavorite] Upserting favorite (recipeId: $effectiveRecipeId) for user: $userId');
      final response = await _client
          .from(AppConstants.favoriteRecipesTable)
          .upsert(data)
          .select()
          .single();

      final fav = FavoriteRecipe.fromJson(response);
      debugPrint('✅ [SupabaseRecipeDataSource.addFavorite] Successfully favorited recipe "${recipe.name}" (id: ${fav.id})');
      return fav;
    } catch (e, st) {
      AppSupabaseClient.logError('addFavorite ("$recipeId")', e, st);
      rethrow;
    }
  }

  Future<void> removeFavorite(String recipeId) async {
    var userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await AppSupabaseClient.ensureAuthenticated();
      userId = _client.auth.currentUser?.id;
      if (userId == null) return;
    }

    try {
      debugPrint('💔 [SupabaseRecipeDataSource.removeFavorite] Deleting favorite (recipeId: $recipeId) for user: $userId');
      await _client
          .from(AppConstants.favoriteRecipesTable)
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
      debugPrint('✅ [SupabaseRecipeDataSource.removeFavorite] Successfully removed favorite $recipeId');
    } catch (e, st) {
      AppSupabaseClient.logError('removeFavorite ("$recipeId")', e, st);
      rethrow;
    }
  }

  Future<bool> isFavorited(String recipeId) async {
    var userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await AppSupabaseClient.ensureAuthenticated();
      userId = _client.auth.currentUser?.id;
      if (userId == null) return false;
    }

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
