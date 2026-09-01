import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../models/recipe.dart';

class EdgeFunctionsDataSource {
  final SupabaseClient _client;

  EdgeFunctionsDataSource(this._client);

  Future<Recipe> generateRecipe({
    required String primaryIngredient,
    List<String> availablePantryItems = const [],
  }) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.generateRecipeFunction,
        body: {
          'primary_ingredient': primaryIngredient,
          'pantry_items': availablePantryItems,
          'mode': 'single_item',
        },
      );

      if (response.status == 429) {
        throw const QuotaExceededException('Monthly recipe generation quota exceeded.');
      }

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Recipe generation failed.';
        throw ServerException(errorMsg.toString());
      }

      final data = response.data as Map<String, dynamic>;
      return Recipe.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Future<Recipe> generateExpiringSoonRecipe({
    required List<String> expiringItems,
  }) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.generateRecipeFunction,
        body: {
          'expiring_items': expiringItems,
          'mode': 'expiring_soon',
        },
      );

      if (response.status == 429) {
        throw const QuotaExceededException('Monthly recipe generation quota exceeded.');
      }

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Recipe generation failed.';
        throw ServerException(errorMsg.toString());
      }

      final data = response.data as Map<String, dynamic>;
      return Recipe.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Future<int> incrementSession() async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.incrementSessionFunction,
      );
      if (response.status == 200 && response.data != null) {
        return (response.data['login_count'] as num?)?.toInt() ?? 1;
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }
}
