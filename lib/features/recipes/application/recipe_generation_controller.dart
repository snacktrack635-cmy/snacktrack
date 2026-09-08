import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    } catch (e, st) {
      debugPrint('❌ [RecipeGenerationController.generateRecipeForItem] Error: $e\n$st');
      final msg = e.toString();
      state = state.copyWith(
        isGenerating: false,
        errorMessage: msg,
        isQuotaExceeded: msg.contains('quota') || msg.contains('429'),
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
    } catch (e, st) {
      debugPrint('❌ [RecipeGenerationController.generateExpiringSoonRecipe] Error: $e\n$st');
      final msg = e.toString();
      state = state.copyWith(
        isGenerating: false,
        errorMessage: msg,
        isQuotaExceeded: msg.contains('quota') || msg.contains('429'),
      );
    }
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
