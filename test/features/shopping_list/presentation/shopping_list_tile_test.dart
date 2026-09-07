import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/shopping_list_item.dart';
import 'package:snacktrack/features/shopping_list/presentation/widgets/shopping_list_tile.dart';

void main() {
  group('ShoppingListTile Widget', () {
    testWidgets('renders unchecked item and triggers checkbox callback', (tester) async {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Olive Oil',
        isChecked: false,
        source: 'manual',
        createdAt: DateTime.now(),
      );

      bool? toggledVal;
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShoppingListTile(
              item: item,
              onCheckboxChanged: (val) => toggledVal = val,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      expect(find.text('Olive Oil'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(toggledVal, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(deleted, isTrue);
    });

    testWidgets('renders item with strikethrough when checked and shows source', (tester) async {
      final item = ShoppingListItem(
        id: 'i-2',
        userId: 'u-1',
        name: 'Garlic Powder',
        isChecked: true,
        source: 'recipe',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShoppingListTile(
              item: item,
            ),
          ),
        ),
      );

      expect(find.text('Garlic Powder'), findsOneWidget);
      expect(find.text('Added from recipe'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Garlic Powder'));
      expect(textWidget.style?.decoration, equals(TextDecoration.lineThrough));
    });
  });
}
