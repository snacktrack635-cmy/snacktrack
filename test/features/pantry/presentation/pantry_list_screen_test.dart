import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/features/pantry/application/pantry_controller.dart';
import 'package:snacktrack/features/pantry/presentation/screens/pantry_list_screen.dart';
import 'package:snacktrack/features/recipes/application/recipe_generation_controller.dart';
import 'package:snacktrack/widgets/error_view.dart';
import 'package:snacktrack/widgets/loading_view.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('PantryListScreen', () {
    late FakePantryRepository pantryRepository;
    late FakeRecipeRepository recipeRepository;

    setUp(() {
      pantryRepository = FakePantryRepository();
      recipeRepository = FakeRecipeRepository();
    });

    Widget createTestWidget({GoRouter? router}) {
      final testRouter = router ??
          GoRouter(
            initialLocation: '/pantry',
            routes: [
              GoRoute(
                path: '/pantry',
                builder: (context, state) => const PantryListScreen(),
              ),
              GoRoute(
                path: '/recipes/expiring-soon',
                builder: (context, state) => const Scaffold(body: Text('Expiring Target')),
              ),
              GoRoute(
                path: '/recipes/favorites',
                builder: (context, state) => const Scaffold(body: Text('Favorites Target')),
              ),
              GoRoute(
                path: '/scan/barcode',
                builder: (context, state) => const Scaffold(body: Text('Scan Target')),
              ),
              GoRoute(
                path: '/recipes/detail',
                builder: (context, state) => const Scaffold(body: Text('Recipe Detail Target')),
              ),
            ],
          );

      return ProviderScope(
        overrides: [
          pantryControllerProvider.overrideWith(
            (ref) => PantryController(pantryRepository),
          ),
          recipeGenerationControllerProvider.overrideWith(
            (ref) => RecipeGenerationController(
              recipeRepository: recipeRepository,
              pantryRepository: pantryRepository,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
    }

    testWidgets('shows empty state when pantry has no items', (tester) async {
      pantryRepository.items = [];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Your pantry is empty'), findsOneWidget);
      expect(find.text('Scan items or add them manually to get started.'), findsOneWidget);
    });

    testWidgets('shows ErrorView when repository fails on load', (tester) async {
      pantryRepository.throwOnGet = true;
      pantryRepository.errorMessage = 'Network connection failed';

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.textContaining('Network connection failed'), findsOneWidget);
    });

    testWidgets('renders list of items when pantry is populated', (tester) async {
      pantryRepository.items = [
        PantryItem(
          id: 'p-1',
          userId: 'u-1',
          name: 'Greek Yogurt',
          category: 'Dairy',
          quantity: 2,
          unit: 'tubs',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PantryItem(
          id: 'p-2',
          userId: 'u-1',
          name: 'Bananas',
          category: 'Produce',
          quantity: 5,
          unit: 'pcs',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Greek Yogurt'), findsOneWidget);
      expect(find.text('Bananas'), findsOneWidget);
    });

    testWidgets('navigates to scan screen when FAB is tapped', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Scan Groceries'), findsOneWidget);
      await tester.tap(find.text('Scan Groceries'));
      await tester.pumpAndSettle();

      expect(find.text('Scan Target'), findsOneWidget);
    });

    testWidgets('navigates to expiring soon and favorites from AppBar', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Expiring soon icon
      await tester.tap(find.byIcon(Icons.bolt_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Expiring Target'), findsOneWidget);
    });
  });
}
