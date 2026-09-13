import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/supabase_client.dart';
import '../models/recipe.dart';

class EdgeFunctionsDataSource {
  final SupabaseClient _client;

  EdgeFunctionsDataSource(this._client);

  Future<Recipe> generateRecipe({
    required String primaryIngredient,
    List<String> availablePantryItems = const [],
    String? pantryItemId,
  }) async {
    try {
      final body = <String, dynamic>{
        'primary_ingredient': primaryIngredient,
        'pantry_items': availablePantryItems,
        'mode': 'single_item',
      };
      if (pantryItemId != null) {
        body['pantryItemId'] = pantryItemId;
        body['pantry_item_id'] = pantryItemId;
      }

      final response = await _client.functions.invoke(
        AppConstants.generateRecipeFunction,
        body: body,
      );

      if (response.status == 429 ||
          (response.status == 403 &&
              response.data is Map &&
              response.data['error'] == 'quota_exceeded')) {
        debugPrint('⚠️ [Supabase Edge Function: ${AppConstants.generateRecipeFunction}] Quota exceeded.');
        throw const QuotaExceededException('Your monthly quota has been reached.', code: 'quota_exceeded');
      }

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Recipe generation failed.';
        debugPrint('❌ [Supabase Edge Function: ${AppConstants.generateRecipeFunction}] HTTP ${response.status}: $errorMsg\nResponse body: ${response.data}');
        throw ServerException(errorMsg.toString());
      }

      final data = response.data as Map<String, dynamic>;
      final recipeData = (data['recipe'] is Map<String, dynamic>)
          ? data['recipe'] as Map<String, dynamic>
          : data;
      return Recipe.fromJson(recipeData);
    } catch (e, st) {
      _handleException(e, st, 'EdgeFunction.generateRecipe ($primaryIngredient)');
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

      if (response.status == 429 ||
          (response.status == 403 &&
              response.data is Map &&
              response.data['error'] == 'quota_exceeded')) {
        debugPrint('⚠️ [Supabase Edge Function: ${AppConstants.generateRecipeFunction}] Quota exceeded.');
        throw const QuotaExceededException('Your monthly quota has been reached.', code: 'quota_exceeded');
      }

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Recipe generation failed.';
        debugPrint('❌ [Supabase Edge Function: ${AppConstants.generateRecipeFunction} (expiring_soon)] HTTP ${response.status}: $errorMsg\nResponse body: ${response.data}');
        throw ServerException(errorMsg.toString());
      }

      final data = response.data as Map<String, dynamic>;
      final recipeData = (data['recipe'] is Map<String, dynamic>)
          ? data['recipe'] as Map<String, dynamic>
          : data;
      return Recipe.fromJson(recipeData);
    } catch (e, st) {
      _handleException(e, st, 'EdgeFunction.generateExpiringSoonRecipe');
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
      debugPrint('⚠️ [Supabase Edge Function: ${AppConstants.incrementSessionFunction}] Non-200 status (${response.status}): ${response.data}');
      return 1;
    } catch (e, st) {
      AppSupabaseClient.logError('EdgeFunction.incrementSession', e, st);
      return 1;
    }
  }

  /// Calls the Supabase Edge Function to identify a food item and estimate expiry date via Gemini
  Future<Map<String, dynamic>> scanFoodItemWithAi({
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final response = await _client.functions.invoke(
        AppConstants.scanFoodItemFunction,
        body: {
          'image': imageBase64,
          'mime_type': mimeType,
          'mode': 'vision_scan',
        },
      );

      if (response.status == 429 ||
          (response.status == 403 &&
              response.data is Map &&
              response.data['error'] == 'quota_exceeded')) {
        debugPrint('⚠️ [Supabase Edge Function: ${AppConstants.scanFoodItemFunction}] HTTP 429 - Quota exceeded.');
        throw const QuotaExceededException('Monthly AI food scan quota exceeded. Please upgrade your subscription.');
      }

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'AI food scan failed.';
        debugPrint('❌ [Supabase Edge Function: ${AppConstants.scanFoodItemFunction}] HTTP ${response.status}: $errorMsg');
        throw ServerException(errorMsg.toString(), code: response.status.toString());
      }

      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      _handleException(
        e,
        st,
        'EdgeFunction.scanFoodItemWithAi',
        quotaMessage: 'Monthly AI food scan quota exceeded. Please upgrade your subscription.',
      );
    }
  }

  Never _handleException(
    dynamic e,
    StackTrace st,
    String operation, {
    String quotaMessage = 'Your monthly quota has been reached.',
  }) {
    AppSupabaseClient.logError(operation, e, st);
    if (e is AppException) throw e;

    if (e is FunctionException) {
      final details = e.details;
      final isQuota = e.status == 429 ||
          (e.status == 403 &&
              details is Map &&
              (details['error']?.toString() == 'quota_exceeded' ||
                  details['message']?.toString().toLowerCase().contains('quota') == true)) ||
          (details is Map &&
              (details['error']?.toString().toLowerCase().contains('quota') == true ||
                  details['message']?.toString().toLowerCase().contains('quota') == true)) ||
          e.toString().toLowerCase().contains('quota_exceeded') ||
          e.toString().toLowerCase().contains('quota exceeded') ||
          e.toString().toLowerCase().contains('limit reached');

      if (isQuota) {
        throw QuotaExceededException(
          quotaMessage,
          code: 'quota_exceeded',
        );
      }

      final message = (details is Map && (details['error'] != null || details['message'] != null))
          ? (details['message'] ?? details['error']).toString()
          : (e.reasonPhrase ?? 'Edge function execution failed.');
      throw ServerException(message, code: e.status.toString());
    }

    throw ServerException(e.toString());
  }
}

