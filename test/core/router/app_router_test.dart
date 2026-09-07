import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/app.dart';
import 'package:snacktrack/core/router/app_router.dart';
import 'package:snacktrack/features/pantry/application/pantry_controller.dart';
import 'package:snacktrack/features/recipes/application/favorites_controller.dart';
import 'package:snacktrack/features/shopping_list/application/shopping_list_controller.dart';
import '../../helpers/mock_repositories.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('App Router & ScaffoldWithNavBar', () {
    late FakePantryRepository pantryRepo;
    late FakeRecipeRepository recipeRepo;
    late FakeShoppingListRepository shoppingRepo;

    setUp(() {
      pantryRepo = FakePantryRepository();
      recipeRepo = FakeRecipeRepository();
      shoppingRepo = FakeShoppingListRepository();
    });

    testWidgets('navigates between bottom navigation bar tabs (Pantry, Recipes, Shopping)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pantryControllerProvider.overrideWith(
              (ref) => PantryController(pantryRepo),
            ),
            favoritesControllerProvider.overrideWith(
              (ref) => FavoritesController(recipeRepo),
            ),
            shoppingListControllerProvider.overrideWith(
              (ref) => ShoppingListController(shoppingRepo),
            ),
          ],
          child: const SnackTrackApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Initial tab is Pantry
      expect(find.text('My Pantry'), findsOneWidget);

      // Tap Recipes tab
      await tester.tap(find.text('Recipes'));
      await tester.pumpAndSettle();

      expect(find.text('Saved Recipes'), findsOneWidget);

      // Tap Shopping tab
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();

      expect(find.text('Shopping List'), findsOneWidget);

      // Tap back to Pantry tab
      await tester.tap(find.text('Pantry'));
      await tester.pumpAndSettle();

      expect(find.text('My Pantry'), findsOneWidget);
    });

    testWidgets('ScaffoldWithNavBar handles default tab selection', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/pantry',
        routes: [
          ShellRoute(
            builder: (context, state, child) => ScaffoldWithNavBar(child: child),
            routes: [
              GoRoute(
                path: '/pantry',
                builder: (context, state) => const Text('Pantry Shell Page'),
              ),
              GoRoute(
                path: '/recipes',
                builder: (context, state) => const Text('Recipes Shell Page'),
              ),
              GoRoute(
                path: '/shopping-list',
                builder: (context, state) => const Text('Shopping Shell Page'),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Pantry'), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
    });
  });
}
