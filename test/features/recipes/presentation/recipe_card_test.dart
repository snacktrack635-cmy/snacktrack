import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/features/recipes/presentation/widgets/recipe_card.dart';

void main() {
  group('RecipeCard Widget', () {
    testWidgets('renders recipe details, ingredients and steps count', (tester) async {
      final recipe = Recipe(
        id: 'r-1',
        name: 'Creamy Garlic Pasta',
        primaryIngredient: 'Garlic',
        ingredients: const [
          RecipeIngredient(name: 'Garlic', quantity: '3 cloves'),
          RecipeIngredient(name: 'Pasta', quantity: '200g'),
          RecipeIngredient(name: 'Heavy Cream', quantity: '100ml'),
        ],
        instructions: const [
          'Boil pasta.',
          'Saute garlic.',
          'Add cream and combine.',
        ],
        createdAt: DateTime.now(),
      );

      bool tapped = false;
      bool favoriteToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeCard(
              recipe: recipe,
              isFavorite: true,
              onTap: () => tapped = true,
              onToggleFavorite: () => favoriteToggled = true,
            ),
          ),
        ),
      );

      // Verify name
      expect(find.text('Creamy Garlic Pasta'), findsOneWidget);

      // Verify primary ingredient badge
      expect(find.text('Garlic'), findsOneWidget);

      // Verify ingredients and steps count
      expect(find.text('3 ingredients • 3 steps'), findsOneWidget);

      // Verify favorite icon is active
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Creamy Garlic Pasta'));
      await tester.pump();
      expect(tapped, isTrue);

      // Tap favorite button
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();
      expect(favoriteToggled, isTrue);
    });

    testWidgets('renders unfavorited icon when isFavorite is false', (tester) async {
      final recipe = Recipe(
        id: 'r-2',
        name: 'Simple Salad',
        ingredients: const [RecipeIngredient(name: 'Lettuce')],
        instructions: const ['Toss and serve.'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeCard(
              recipe: recipe,
              isFavorite: false,
            ),
          ),
        ),
      );

      expect(find.text('Simple Salad'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}
