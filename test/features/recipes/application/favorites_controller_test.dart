import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/features/recipes/application/favorites_controller.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('FavoritesController', () {
    late FakeRecipeRepository repository;
    late FavoritesController controller;

    setUp(() {
      repository = FakeRecipeRepository();
      controller = FavoritesController(repository);
    });

    test('initial state loads favorites successfully', () async {
      final recipe = Recipe(
        id: 'r-1',
        name: 'French Toast',
        ingredients: const [],
        instructions: const [],
        createdAt: DateTime.now(),
      );
      repository.favorites = [
        FavoriteRecipe(
          id: 'fav-1',
          userId: 'u-1',
          recipeId: 'r-1',
          recipeSnapshot: recipe,
          createdAt: DateTime.now(),
        ),
      ];

      await controller.loadFavorites();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.favorites.length, equals(1));
      expect(controller.state.errorMessage, isNull);
    });

    test('loadFavorites sets errorMessage on failure', () async {
      repository.throwOnFavorites = true;
      repository.errorMessage = 'Database down';

      await controller.loadFavorites();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.favorites, isEmpty);
      expect(controller.state.errorMessage, contains('Failed to load favorites'));
    });

    test('toggleFavorite adds recipe when not in favorites', () async {
      final recipe = Recipe(
        id: 'r-2',
        name: 'Guacamole',
        ingredients: const [],
        instructions: const [],
        createdAt: DateTime.now(),
      );

      await controller.toggleFavorite(recipe);

      expect(controller.state.favorites.length, equals(1));
      expect(controller.state.favorites.first.recipeId, equals('r-2'));
      expect(controller.state.errorMessage, isNull);
    });

    test('toggleFavorite sets errorMessage when adding favorite fails', () async {
      repository.throwOnAddFavorite = true;
      repository.errorMessage = 'Foreign key constraint violated';

      final recipe = Recipe(
        id: 'r-fail',
        name: 'Failure Dish',
        ingredients: const [],
        instructions: const [],
        createdAt: DateTime.now(),
      );

      await controller.toggleFavorite(recipe);

      expect(controller.state.favorites, isEmpty);
      expect(controller.state.errorMessage, contains('Failed to add favorite'));
    });

    test('toggleFavorite removes recipe when already in favorites', () async {
      final recipe = Recipe(
        id: 'r-1',
        name: 'French Toast',
        ingredients: const [],
        instructions: const [],
        createdAt: DateTime.now(),
      );
      repository.favorites = [
        FavoriteRecipe(
          id: 'fav-1',
          userId: 'u-1',
          recipeId: 'r-1',
          recipeSnapshot: recipe,
          createdAt: DateTime.now(),
        ),
      ];
      await controller.loadFavorites();

      await controller.toggleFavorite(recipe);

      expect(controller.state.favorites, isEmpty);
      expect(controller.state.errorMessage, isNull);
    });

    test('toggleFavorite sets errorMessage when removing favorite fails', () async {
      final recipe = Recipe(
        id: 'r-1',
        name: 'French Toast',
        ingredients: const [],
        instructions: const [],
        createdAt: DateTime.now(),
      );
      repository.favorites = [
        FavoriteRecipe(
          id: 'fav-1',
          userId: 'u-1',
          recipeId: 'r-1',
          recipeSnapshot: recipe,
          createdAt: DateTime.now(),
        ),
      ];
      await controller.loadFavorites();

      repository.throwOnRemoveFavorite = true;
      repository.errorMessage = 'Delete permission denied';

      await controller.toggleFavorite(recipe);

      expect(controller.state.errorMessage, contains('Failed to remove favorite'));
    });

    test('isFavorite checks correctly by id or recipe name', () async {
      final recipe = Recipe(
        id: 'r-10',
        name: 'Apple Pie',
        ingredients: const [],
        instructions: const [],
        createdAt: DateTime.now(),
      );
      repository.favorites = [
        FavoriteRecipe(
          id: 'fav-10',
          userId: 'u-1',
          recipeId: 'r-10',
          recipeSnapshot: recipe,
          createdAt: DateTime.now(),
        ),
      ];
      await controller.loadFavorites();

      expect(controller.isFavorite('r-10', null), isTrue);
      expect(controller.isFavorite(null, 'Apple Pie'), isTrue);
      expect(controller.isFavorite('r-999', 'Other Pie'), isFalse);
    });
  });
}
