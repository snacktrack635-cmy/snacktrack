import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/errors/exceptions.dart';
import 'package:snacktrack/data/datasources/edge_functions_ds.dart';
import 'package:snacktrack/data/datasources/supabase_recipe_ds.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/data/repositories/recipe_repository.dart';

class StubRecipeDataSource implements SupabaseRecipeDataSource {
  Recipe? cachedRecipe;
  List<FavoriteRecipe> favorites = [];
  bool throwOnFavorites = false;
  bool isFavoritedResult = false;

  @override
  Future<Recipe?> getCachedRecipe({
    required String normalizedName,
    String? primaryIngredient,
  }) async {
    return cachedRecipe;
  }

  @override
  Future<List<FavoriteRecipe>> getFavorites() async {
    if (throwOnFavorites) throw Exception('Failed to get favorites');
    return favorites;
  }

  @override
  Future<FavoriteRecipe> addFavorite({
    required String recipeId,
    required Recipe recipe,
  }) async {
    final fav = FavoriteRecipe(
      id: 'fav-1',
      userId: 'u-1',
      recipeId: recipeId,
      recipeSnapshot: recipe,
      createdAt: DateTime.now(),
    );
    favorites.add(fav);
    return fav;
  }

  @override
  Future<void> removeFavorite(String recipeId) async {
    favorites.removeWhere((f) => f.recipeId == recipeId);
  }

  @override
  Future<bool> isFavorited(String recipeId) async {
    return isFavoritedResult;
  }
}

class StubEdgeFunctionsDataSource implements EdgeFunctionsDataSource {
  Recipe? edgeRecipe;
  bool throwQuota = false;
  bool throwServer = false;
  int generateRecipeCalls = 0;

  @override
  Future<Recipe> generateRecipe({
    required String primaryIngredient,
    List<String> availablePantryItems = const [],
    String? pantryItemId,
  }) async {
    generateRecipeCalls++;
    if (throwQuota) throw const QuotaExceededException('Quota exceeded');
    if (throwServer) throw const ServerException('Server failed');
    return edgeRecipe ??
        Recipe(
          id: 'edge-1',
          name: 'Edge Generated $primaryIngredient',
          ingredients: [RecipeIngredient(name: primaryIngredient)],
          instructions: ['Cook and serve.'],
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<Recipe> generateExpiringSoonRecipe({
    required List<String> expiringItems,
  }) async {
    if (throwQuota) throw const QuotaExceededException('Quota exceeded');
    if (throwServer) throw const ServerException('Server failed');
    return edgeRecipe ??
        Recipe(
          id: 'edge-exp-1',
          name: 'Zero Waste Soup',
          ingredients: expiringItems.map((e) => RecipeIngredient(name: e)).toList(),
          instructions: ['Simmer all.'],
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<int> incrementSession() async => 1;

  @override
  Future<Map<String, dynamic>> scanFoodItemWithAi({
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async =>
      {};
}

void main() {
  group('RecipeRepository', () {
    late StubRecipeDataSource recipeDataSource;
    late StubEdgeFunctionsDataSource edgeFunctionsDataSource;
    late RecipeRepository repository;

    setUp(() {
      recipeDataSource = StubRecipeDataSource();
      edgeFunctionsDataSource = StubEdgeFunctionsDataSource();
      repository = RecipeRepository(
        recipeDataSource: recipeDataSource,
        edgeFunctionsDataSource: edgeFunctionsDataSource,
      );
    });

    test('generateRecipe returns cached recipe if cache hits (no edge function call)', () async {
      final cached = Recipe(
        id: 'cached-1',
        name: 'Cached Pasta',
        normalizedName: 'pasta',
        ingredients: const [RecipeIngredient(name: 'Pasta')],
        instructions: const ['Boil.'],
        createdAt: DateTime.now(),
      );
      recipeDataSource.cachedRecipe = cached;

      final recipe = await repository.generateRecipe(primaryIngredient: 'Pasta');

      expect(recipe.id, equals('cached-1'));
      expect(recipe.name, equals('Cached Pasta'));
      expect(edgeFunctionsDataSource.generateRecipeCalls, equals(0));
    });

    test('generateRecipe calls Edge Function when cache misses', () async {
      recipeDataSource.cachedRecipe = null;

      final recipe = await repository.generateRecipe(
        primaryIngredient: 'Salmon',
        availablePantryItems: ['Lemon', 'Dill'],
      );

      expect(recipe.id, equals('edge-1'));
      expect(edgeFunctionsDataSource.generateRecipeCalls, equals(1));
    });

    test('generateRecipe propagates QuotaExceededException on rate limit', () async {
      recipeDataSource.cachedRecipe = null;
      edgeFunctionsDataSource.throwQuota = true;

      expect(
        () => repository.generateRecipe(primaryIngredient: 'Steak'),
        throwsA(isA<QuotaExceededException>()),
      );
    });

    test('generateExpiringSoonRecipe propagates ServerException on failure', () async {
      edgeFunctionsDataSource.throwServer = true;

      expect(
        () => repository.generateExpiringSoonRecipe(expiringItems: ['Milk', 'Spinach']),
        throwsA(isA<ServerException>()),
      );
    });

    test('getFavorites delegates to recipe data source', () async {
      recipeDataSource.favorites = [
        FavoriteRecipe(
          id: 'f-1',
          userId: 'u-1',
          recipeId: 'r-1',
          recipeSnapshot: Recipe(
            id: 'r-1',
            name: 'Pancakes',
            ingredients: const [],
            instructions: const [],
            createdAt: DateTime.now(),
          ),
          createdAt: DateTime.now(),
        ),
      ];

      final favs = await repository.getFavorites();
      expect(favs.length, equals(1));
      expect(favs.first.recipeSnapshot.name, equals('Pancakes'));
    });

    test('addFavorite and removeFavorite delegate properly', () async {
      final recipe = Recipe(
        id: 'r-2',
        name: 'Waffles',
        ingredients: const [],
        instructions: const [],
        createdAt: DateTime.now(),
      );

      final added = await repository.addFavorite(recipe);
      expect(added.recipeId, equals('r-2'));
      expect(recipeDataSource.favorites.length, equals(1));

      await repository.removeFavorite('r-2');
      expect(recipeDataSource.favorites, isEmpty);
    });

    test('isFavorited delegates to recipe data source', () async {
      recipeDataSource.isFavoritedResult = true;
      expect(await repository.isFavorited('r-1'), isTrue);

      recipeDataSource.isFavoritedResult = false;
      expect(await repository.isFavorited('r-2'), isFalse);
    });
  });
}
