import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../data/models/recipe.dart';
import '../../../data/repositories/pantry_repository.dart';
import '../../../data/repositories/recipe_repository.dart';
import '../../../providers/global_providers.dart';

class RecipeGenerationState {
  final bool isGenerating;
  final Recipe? currentRecipe;
  final String? errorMessage;
  final bool isQuotaExceeded;

  const RecipeGenerationState({
    this.isGenerating = false,
    this.currentRecipe,
    this.errorMessage,
    this.isQuotaExceeded = false,
  });

  RecipeGenerationState copyWith({
    bool? isGenerating,
    Recipe? currentRecipe,
    bool clearRecipe = false,
    String? errorMessage,
    bool? isQuotaExceeded,
  }) {
    return RecipeGenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      currentRecipe: clearRecipe ? null : (currentRecipe ?? this.currentRecipe),
      errorMessage: errorMessage,
      isQuotaExceeded: isQuotaExceeded ?? this.isQuotaExceeded,
    );
  }
}

class RecipeGenerationController extends StateNotifier<RecipeGenerationState> {
  static const String quotaExceededMessage = 'Your monthly quota has been reached.';

  final RecipeRepository _recipeRepository;
  final PantryRepository _pantryRepository;

  RecipeGenerationController({
    required RecipeRepository recipeRepository,
    required PantryRepository pantryRepository,
  })  : _recipeRepository = recipeRepository,
        _pantryRepository = pantryRepository,
        super(const RecipeGenerationState());

  Future<void> generateRecipeForItem(
    String primaryIngredient, {
    String? pantryItemId,
  }) async {
    state = state.copyWith(
      isGenerating: true,
      clearRecipe: true,
      errorMessage: null,
      isQuotaExceeded: false,
    );

    try {
      // Fetch user's pantry items as context for secondary ingredients
      final pantryItems = await _pantryRepository.getPantryItems();
      final secondaryIngredients = pantryItems
          .where((item) => item.name.toLowerCase() != primaryIngredient.toLowerCase())
          .map((item) => item.name)
          .toList();

      final recipe = await _recipeRepository.generateRecipe(
        primaryIngredient: primaryIngredient,
        availablePantryItems: secondaryIngredients,
        pantryItemId: pantryItemId,
      );

      state = state.copyWith(
        isGenerating: false,
        currentRecipe: recipe,
      );
    } on QuotaExceededException catch (e) {
      debugPrint('⚠️ [RecipeGenerationController.generateRecipeForItem] Quota exceeded: $e');
      state = state.copyWith(
        isGenerating: false,
        errorMessage: quotaExceededMessage,
        isQuotaExceeded: true,
      );
    } catch (e, st) {
      final isQuota = _isQuotaError(e);
      if (isQuota) {
        debugPrint('⚠️ [RecipeGenerationController.generateRecipeForItem] Quota exceeded: $e');
      } else {
        debugPrint('❌ [RecipeGenerationController.generateRecipeForItem] Error: $e\n$st');
      }
      state = state.copyWith(
        isGenerating: false,
        errorMessage: isQuota ? quotaExceededMessage : _getErrorMessage(e),
        isQuotaExceeded: isQuota,
      );
    }
  }

  Future<void> generateExpiringSoonRecipe() async {
    state = state.copyWith(
      isGenerating: true,
      clearRecipe: true,
      errorMessage: null,
      isQuotaExceeded: false,
    );

    try {
      final expiringItems = await _pantryRepository.getExpiringSoonItems(daysThreshold: 3);
      final ingredientNames = expiringItems.map((e) => e.name).toList();

      if (ingredientNames.isEmpty) {
        state = state.copyWith(
          isGenerating: false,
          errorMessage: 'No items are expiring soon in your pantry!',
        );
        return;
      }

      final recipe = await _recipeRepository.generateExpiringSoonRecipe(
        expiringItems: ingredientNames,
      );

      state = state.copyWith(
        isGenerating: false,
        currentRecipe: recipe,
      );
    } on QuotaExceededException catch (e) {
      debugPrint('⚠️ [RecipeGenerationController.generateExpiringSoonRecipe] Quota exceeded: $e');
      state = state.copyWith(
        isGenerating: false,
        errorMessage: quotaExceededMessage,
        isQuotaExceeded: true,
      );
    } catch (e, st) {
      final isQuota = _isQuotaError(e);
      if (isQuota) {
        debugPrint('⚠️ [RecipeGenerationController.generateExpiringSoonRecipe] Quota exceeded: $e');
      } else {
        debugPrint('❌ [RecipeGenerationController.generateExpiringSoonRecipe] Error: $e\n$st');
      }
      state = state.copyWith(
        isGenerating: false,
        errorMessage: isQuota ? quotaExceededMessage : _getErrorMessage(e),
        isQuotaExceeded: isQuota,
      );
    }
  }

  bool _isQuotaError(dynamic error) {
    if (error is QuotaExceededException) return true;
    final str = error.toString().toLowerCase();
    return str.contains('quota_exceeded') ||
        str.contains('quota exceeded') ||
        str.contains('monthly recipe generation limit reached') ||
        str.contains('limit reached') ||
        str.contains('monthly quota') ||
        (str.contains('403') && str.contains('quota')) ||
        str.contains('429');
  }

  String _getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    final str = error.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length);
    }
    return str;
  }
}

final recipeGenerationControllerProvider =
    StateNotifierProvider<RecipeGenerationController, RecipeGenerationState>((ref) {
  final recipeRepo = ref.watch(recipeRepositoryProvider);
  final pantryRepo = ref.watch(pantryRepositoryProvider);
  return RecipeGenerationController(
    recipeRepository: recipeRepo,
    pantryRepository: pantryRepo,
  );
});
