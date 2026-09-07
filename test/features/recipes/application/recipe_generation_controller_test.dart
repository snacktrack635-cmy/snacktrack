import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/features/recipes/application/recipe_generation_controller.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('RecipeGenerationController', () {
    late FakeRecipeRepository recipeRepository;
    late FakePantryRepository pantryRepository;
    late RecipeGenerationController controller;

    setUp(() {
      recipeRepository = FakeRecipeRepository();
      pantryRepository = FakePantryRepository();
      controller = RecipeGenerationController(
        recipeRepository: recipeRepository,
        pantryRepository: pantryRepository,
      );
    });

    test('initial state has correct defaults', () {
      expect(controller.state.isGenerating, isFalse);
      expect(controller.state.currentRecipe, isNull);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isQuotaExceeded, isFalse);
    });

    test('generateRecipeForItem succeeds and sets currentRecipe', () async {
      pantryRepository.items = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Olive Oil',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PantryItem(
          id: 'p-2',
          userId: 'u-1',
          name: 'Garlic',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await controller.generateRecipeForItem('Chicken');

      expect(controller.state.isGenerating, isFalse);
      expect(controller.state.currentRecipe, isNotNull);
      expect(controller.state.currentRecipe!.name, contains('Chicken'));
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isQuotaExceeded, isFalse);
    });

    test('generateRecipeForItem sets isQuotaExceeded on HTTP 429 quota failure', () async {
      recipeRepository.throwQuotaOnGenerate = true;

      await controller.generateRecipeForItem('Steak');

      expect(controller.state.isGenerating, isFalse);
      expect(controller.state.currentRecipe, isNull);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.isQuotaExceeded, isTrue);
    });

    test('generateRecipeForItem sets generic error message on standard failure', () async {
      recipeRepository.throwOnGenerate = true;
      recipeRepository.errorMessage = 'Connection refused';

      await controller.generateRecipeForItem('Fish');

      expect(controller.state.isGenerating, isFalse);
      expect(controller.state.currentRecipe, isNull);
      expect(controller.state.errorMessage, contains('Connection refused'));
      expect(controller.state.isQuotaExceeded, isFalse);
    });

    test('generateExpiringSoonRecipe errors when no pantry items are expiring soon', () async {
      pantryRepository.expiringItems = [];

      await controller.generateExpiringSoonRecipe();

      expect(controller.state.isGenerating, isFalse);
      expect(controller.state.currentRecipe, isNull);
      expect(
        controller.state.errorMessage,
        equals('No items are expiring soon in your pantry!'),
      );
      expect(controller.state.isQuotaExceeded, isFalse);
    });

    test('generateExpiringSoonRecipe succeeds when expiring items are present', () async {
      pantryRepository.expiringItems = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Milk',
          expiryDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PantryItem(
          id: 'p-2',
          userId: 'u-1',
          name: 'Eggs',
          expiryDate: DateTime.now().add(const Duration(days: 2)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await controller.generateExpiringSoonRecipe();

      expect(controller.state.isGenerating, isFalse);
      expect(controller.state.currentRecipe, isNotNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('generateExpiringSoonRecipe sets isQuotaExceeded when quota is exceeded', () async {
      pantryRepository.expiringItems = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Spinach',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      recipeRepository.throwQuotaOnExpiring = true;

      await controller.generateExpiringSoonRecipe();

      expect(controller.state.isGenerating, isFalse);
      expect(controller.state.currentRecipe, isNull);
      expect(controller.state.isQuotaExceeded, isTrue);
    });
  });
}
