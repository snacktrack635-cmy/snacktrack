import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/shopping_list_item.dart';
import 'package:snacktrack/features/shopping_list/application/shopping_list_controller.dart';
import 'package:snacktrack/features/shopping_list/presentation/screens/shopping_list_screen.dart';
import 'package:snacktrack/widgets/error_view.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('ShoppingListScreen', () {
    late FakeShoppingListRepository repository;

    setUp(() {
      repository = FakeShoppingListRepository();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          shoppingListControllerProvider.overrideWith(
            (ref) => ShoppingListController(repository),
          ),
        ],
        child: const MaterialApp(
          home: ShoppingListScreen(),
        ),
      );
    }

    testWidgets('displays empty state when list has no items', (tester) async {
      repository.items = [];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Your shopping list is empty'), findsOneWidget);
    });

    testWidgets('displays ErrorView when loading items fails', (tester) async {
      repository.throwOnGet = true;
      repository.errorMessage = 'Network connection dropped';

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.textContaining('Network connection dropped'), findsOneWidget);
    });

    testWidgets('adds item via text input and add button', (tester) async {
      repository.items = [];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Soy Sauce');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(repository.items.length, equals(1));
      expect(repository.items.first.name, equals('Soy Sauce'));
      expect(find.text('Soy Sauce'), findsOneWidget);
    });

    testWidgets('renders list of items and clears completed', (tester) async {
      repository.items = [
        ShoppingListItem(
          id: 'i-1',
          userId: 'u-1',
          name: 'Eggs',
          isChecked: true,
          createdAt: DateTime.now(),
        ),
        ShoppingListItem(
          id: 'i-2',
          userId: 'u-1',
          name: 'Flour',
          isChecked: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('Flour'), findsOneWidget);

      // Tap clear completed
      await tester.tap(find.byIcon(Icons.cleaning_services_rounded));
      await tester.pumpAndSettle();

      expect(repository.items.length, equals(1));
      expect(repository.items.first.name, equals('Flour'));
    });
  });
}
