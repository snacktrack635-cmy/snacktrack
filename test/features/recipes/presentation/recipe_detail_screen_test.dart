import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/features/recipes/application/favorites_controller.dart';
import 'package:snacktrack/features/recipes/application/recipe_generation_controller.dart';
import 'package:snacktrack/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:snacktrack/features/shopping_list/application/shopping_list_controller.dart';
import 'package:snacktrack/widgets/could_not_find_recipe_view.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('RecipeDetailScreen', () {
    late FakeRecipeRepository recipeRepo;
    late FakePantryRepository pantryRepo;
    late FakeShoppingListRepository shoppingRepo;

    setUp(() {
      recipeRepo = FakeRecipeRepository();
      pantryRepo = FakePantryRepository();
      shoppingRepo = FakeShoppingListRepository();
    });

    Widget createTestWidget({
      Recipe? initialRecipe,
      RecipeGenerationState? forcedState,
    }) {
      final router = GoRouter(
        initialLocation: '/recipes/detail',
        routes: [
          GoRoute(
            path: '/recipes/detail',
            builder: (context, state) => RecipeDetailScreen(initialRecipe: initialRecipe),
          ),
          GoRoute(
            path: '/subscription/paywall',
            builder: (context, state) => const Scaffold(body: Text('Paywall Screen')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          recipeGenerationControllerProvider.overrideWith(
            (ref) {
              final controller = RecipeGenerationController(
                recipeRepository: recipeRepo,
                pantryRepository: pantryRepo,
              );
              if (forcedState != null) {
                controller.state = forcedState;
              }
              return controller;
            },
          ),
          favoritesControllerProvider.overrideWith(
            (ref) => FavoritesController(recipeRepo),
          ),
          shoppingListControllerProvider.overrideWith(
            (ref) => ShoppingListController(shoppingRepo),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('displays LoadingView when recipe is generating and no recipe loaded', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          forcedState: const RecipeGenerationState(isGenerating: true),
        ),
      );

      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.text('Gemini AI is crafting your recipe based on your pantry...'), findsOneWidget);
    });

    testWidgets('displays ErrorView and Upgrade button when quota is exceeded', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          forcedState: const RecipeGenerationState(
            errorMessage: 'Monthly recipe quota exceeded (429)',
            isQuotaExceeded: true,
          ),
        ),
      );

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Monthly recipe quota exceeded (429)'), findsOneWidget);
      expect(find.text('Upgrade Subscription'), findsOneWidget);

      await tester.tap(find.text('Upgrade Subscription'));
      await tester.pumpAndSettle();

      expect(find.text('Paywall Screen'), findsOneWidget);
    });

    testWidgets('displays recipe details, ingredients, and instructions when loaded', (tester) async {
      final recipe = Recipe(
        id: 'r-1',
        name: 'Crispy Garlic Chicken',
        primaryIngredient: 'Chicken Breast',
        ingredients: const [
          RecipeIngredient(name: 'Chicken Breast', quantity: '500g'),
          RecipeIngredient(name: 'Garlic', quantity: '3 cloves'),
        ],
        instructions: const [
          'Season chicken breasts with salt and minced garlic.',
          'Pan sear for 6 minutes each side until golden.',
        ],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(initialRecipe: recipe));
      await tester.pumpAndSettle();

      expect(find.text('Crispy Garlic Chicken'), findsAtLeastNWidgets(1));
      expect(find.text('Featured Ingredient: Chicken Breast'), findsOneWidget);
      expect(find.text('Chicken Breast'), findsAtLeastNWidgets(1));
      expect(find.text('500g'), findsOneWidget);
      expect(find.text('Garlic'), findsOneWidget);
      expect(find.text('Pan sear for 6 minutes each side until golden.'), findsOneWidget);
    });

    testWidgets('adds ingredients to shopping list when button is tapped', (tester) async {
      final recipe = Recipe(
        id: 'r-2',
        name: 'Quick Salad',
        ingredients: const [
          RecipeIngredient(name: 'Lettuce'),
          RecipeIngredient(name: 'Olive Oil'),
        ],
        instructions: const ['Toss everything together.'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(initialRecipe: recipe));
      await tester.pumpAndSettle();

      expect(find.text('Add to Shopping List'), findsOneWidget);
      await tester.tap(find.text('Add to Shopping List'));
      await tester.pumpAndSettle();

      expect(find.text('Ingredients added to your shopping list!'), findsOneWidget);
      expect(shoppingRepo.items.length, equals(2));
      expect(shoppingRepo.items.any((i) => i.name == 'Lettuce'), isTrue);
    });

    testWidgets('displays CouldNotFindRecipeView when recipe is Untitled Recipe', (tester) async {
      final untitledRecipe = Recipe(
        id: 'r-empty',
        name: 'Untitled Recipe',
        ingredients: const [],
        instructions: const [],
        primaryIngredient: 'Apples',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(initialRecipe: untitledRecipe));
      await tester.pumpAndSettle();

      expect(find.byType(CouldNotFindRecipeView), findsOneWidget);
      expect(find.text('Could Not Find Recipe'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Apples'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Back to Pantry'), findsOneWidget);
    });

    testWidgets('displays CouldNotFindRecipeView when recipe is null and not generating', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          forcedState: const RecipeGenerationState(isGenerating: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CouldNotFindRecipeView), findsOneWidget);
      expect(find.text('Could Not Find Recipe'), findsAtLeastNWidgets(1));
    });
  });
}
