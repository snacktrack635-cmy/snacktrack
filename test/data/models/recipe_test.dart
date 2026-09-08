import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/recipe.dart';

void main() {
  group('RecipeIngredient', () {
    test('fromJson handles map with string and num quantities', () {
      final ing1 = RecipeIngredient.fromJson({'name': 'Sugar', 'quantity': '2 tbsp'});
      expect(ing1.name, equals('Sugar'));
      expect(ing1.quantity, equals('2 tbsp'));

      final ing2 = RecipeIngredient.fromJson({'name': 'Eggs', 'quantity': 3});
      expect(ing2.name, equals('Eggs'));
      expect(ing2.quantity, equals('3'));

      final ing3 = RecipeIngredient.fromJson({});
      expect(ing3.name, equals(''));
      expect(ing3.quantity, isNull);
    });

    test('toJson serializes correctly', () {
      const ing = RecipeIngredient(name: 'Flour', quantity: '500g');
      final json = ing.toJson();
      expect(json['name'], equals('Flour'));
      expect(json['quantity'], equals('500g'));
    });
  });

  group('Recipe', () {
    test('fromJson parses ingredients as List of Maps', () {
      final json = {
        'id': 'r-100',
        'name': 'Tomato Pasta',
        'normalized_name': 'tomato pasta',
        'ingredients': [
          {'name': 'Pasta', 'quantity': '200g'},
          {'name': 'Tomatoes', 'quantity': '3 pcs'},
        ],
        'instructions': [
          'Boil pasta in salted water.',
          'Saute tomatoes and mix.',
        ],
        'primary_ingredient': 'Tomatoes',
        'source': 'gemini',
        'generation_count': 2,
        'created_at': '2026-09-01T12:00:00.000Z',
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.id, equals('r-100'));
      expect(recipe.name, equals('Tomato Pasta'));
      expect(recipe.normalizedName, equals('tomato pasta'));
      expect(recipe.ingredients.length, equals(2));
      expect(recipe.ingredients[0].name, equals('Pasta'));
      expect(recipe.instructions.length, equals(2));
      expect(recipe.primaryIngredient, equals('Tomatoes'));
      expect(recipe.generationCount, equals(2));
    });

    test('fromJson parses ingredients as List of Strings', () {
      final json = {
        'name': 'Simple Salad',
        'ingredients': ['Lettuce', 'Cucumber', 'Olive Oil'],
        'instructions': ['Chop ingredients and mix with oil.'],
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.ingredients.length, equals(3));
      expect(recipe.ingredients[0].name, equals('Lettuce'));
      expect(recipe.ingredients[1].name, equals('Cucumber'));
      expect(recipe.ingredients[2].name, equals('Olive Oil'));
    });

    test('fromJson handles empty or malformed ingredients and instructions', () {
      final json = {
        'ingredients': 'not-a-list',
        'instructions': 'not-a-list',
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.name, equals('Untitled Recipe'));
      expect(recipe.ingredients, isEmpty);
      expect(recipe.instructions, isEmpty);
      expect(recipe.generationCount, equals(1));
    });

    test('fromJson unwraps nested recipe object from Edge Function response', () {
      final json = {
        'recipe': {
          'id': 'r-nested-1',
          'name': 'Garlic Bread',
          'ingredients': [
            {'name': 'Baguette', 'quantity': '1 loaf'},
            {'name': 'Garlic Butter', 'quantity': '50g'},
          ],
          'instructions': ['Slice and bake with butter.'],
        },
        'cacheHit': true,
      };

      final recipe = Recipe.fromJson(json);
      expect(recipe.id, equals('r-nested-1'));
      expect(recipe.name, equals('Garlic Bread'));
      expect(recipe.ingredients.length, equals(2));
      expect(recipe.instructions.first, equals('Slice and bake with butter.'));
    });

    test('toJson serializes recipe correctly', () {
      final now = DateTime(2026, 9, 10);
      final recipe = Recipe(
        id: 'r-1',
        name: 'Omelette',
        normalizedName: 'omelette',
        ingredients: const [RecipeIngredient(name: 'Eggs', quantity: '2')],
        instructions: const ['Whisk and fry.'],
        primaryIngredient: 'Eggs',
        source: 'cache',
        generationCount: 1,
        createdAt: now,
      );

      final json = recipe.toJson();
      expect(json['id'], equals('r-1'));
      expect(json['name'], equals('Omelette'));
      expect(json['normalized_name'], equals('omelette'));
      expect(json['ingredients'], isA<List>());
      expect(json['instructions'], equals(['Whisk and fry.']));
      expect(json['created_at'], equals(now.toIso8601String()));
    });
  });

  group('FavoriteRecipe', () {
    test('fromJson and toJson round-trip preserves state', () {
      final recipe = Recipe(
        id: 'r-1',
        name: 'Avocado Toast',
        ingredients: const [RecipeIngredient(name: 'Avocado')],
        instructions: const ['Mash and toast.'],
        createdAt: DateTime(2026, 9, 1),
      );

      final json = {
        'id': 'fav-1',
        'user_id': 'u-1',
        'recipe_id': 'r-1',
        'recipe_snapshot': recipe.toJson(),
        'created_at': '2026-09-02T10:00:00.000Z',
      };

      final fav = FavoriteRecipe.fromJson(json);
      expect(fav.id, equals('fav-1'));
      expect(fav.userId, equals('u-1'));
      expect(fav.recipeId, equals('r-1'));
      expect(fav.recipeSnapshot.name, equals('Avocado Toast'));

      final serialized = fav.toJson();
      expect(serialized['id'], equals('fav-1'));
      expect(serialized['recipe_id'], equals('r-1'));
      expect(serialized['recipe_snapshot']['name'], equals('Avocado Toast'));
    });
  });
}
