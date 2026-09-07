import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/data/models/recipe.dart';
import 'package:snacktrack/features/recipes/application/recipe_generation_controller.dart';
import 'package:snacktrack/features/recipes/presentation/screens/expiring_soon_recipes_screen.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('ExpiringSoonRecipesScreen', () {
    late FakeRecipeRepository recipeRepo;
    late FakePantryRepository pantryRepo;

    setUp(() {
      recipeRepo = FakeRecipeRepository();
      pantryRepo = FakePantryRepository();
    });

    Widget createTestWidget() {
      final router = GoRouter(
        initialLocation: '/recipes/expiring-soon',
        routes: [
          GoRoute(
            path: '/recipes/expiring-soon',
            builder: (context, state) => const ExpiringSoonRecipesScreen(),
          ),
          GoRoute(
            path: '/recipes/detail',
            builder: (context, state) => const Scaffold(body: Text('Detail Target')),
          ),
          GoRoute(
            path: '/subscription/paywall',
            builder: (context, state) => const Scaffold(body: Text('Paywall Target')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          recipeGenerationControllerProvider.overrideWith(
            (ref) => RecipeGenerationController(
              recipeRepository: recipeRepo,
              pantryRepository: pantryRepo,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('shows ErrorView when no items are expiring soon', (tester) async {
      pantryRepo.expiringItems = [];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('No items are expiring soon in your pantry!'), findsOneWidget);
    });

    testWidgets('shows Zero-Waste recommendation banner and navigates to steps when recipe exists', (tester) async {
      pantryRepo.expiringItems = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Yogurt',
          expiryDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      recipeRepo.expiringSoonRecipeToReturn = Recipe(
        id: 'r-exp',
        name: 'Yogurt Parfait Bowl',
        ingredients: const [RecipeIngredient(name: 'Yogurt')],
        instructions: const ['Layer with honey and berries.'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Zero-Waste Recommendation'), findsOneWidget);
      expect(find.text('View Full Cooking Steps'), findsOneWidget);

      await tester.tap(find.text('View Full Cooking Steps'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Target'), findsOneWidget);
    });

    testWidgets('shows Upgrade Subscription button when quota exceeded', (tester) async {
      pantryRepo.expiringItems = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Cheese',
          expiryDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      recipeRepo.throwQuotaOnExpiring = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Upgrade Subscription'), findsOneWidget);

      await tester.tap(find.text('Upgrade Subscription'));
      await tester.pumpAndSettle();

      expect(find.text('Paywall Target'), findsOneWidget);
    });
  });
}
