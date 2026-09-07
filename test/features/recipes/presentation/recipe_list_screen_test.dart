import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/features/recipes/application/favorites_controller.dart';
import 'package:snacktrack/features/recipes/presentation/screens/recipe_list_screen.dart';
import 'package:snacktrack/widgets/error_view.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('RecipeListScreen', () {
    late FakeRecipeRepository repository;

    setUp(() {
      repository = FakeRecipeRepository();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          favoritesControllerProvider.overrideWith(
            (ref) => FavoritesController(repository),
          ),
        ],
        child: const MaterialApp(
          home: RecipeListScreen(),
        ),
      );
    }

    testWidgets('shows empty state when no favorite recipes exist', (tester) async {
      repository.favorites = [];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No saved recipes yet'), findsOneWidget);
    });

    testWidgets('shows ErrorView when loading favorites fails', (tester) async {
      repository.throwOnFavorites = true;
      repository.errorMessage = 'Connection refused';

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);
    });

    testWidgets('renders list of favorite recipes', (tester) async {
      repository.favorites = [
        FavoriteRecipe(
          id: 'fav-1',
          userId: 'u-1',
          recipeId: 'r-1',
          recipeSnapshot: Recipe(
            id: 'r-1',
            name: 'Creamy Mushroom Risotto',
            ingredients: const [RecipeIngredient(name: 'Rice'), RecipeIngredient(name: 'Mushrooms')],
            instructions: const ['Cook rice with broth.', 'Add sauteed mushrooms.'],
            createdAt: DateTime.now(),
          ),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Creamy Mushroom Risotto'), findsOneWidget);
      expect(find.text('2 ingredients • 2 steps'), findsOneWidget);
    });
  });
}
