import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/pantry_item.dart';
import 'package:snacktrack/features/pantry/presentation/widgets/pantry_item_card.dart';

void main() {
  group('PantryItemCard Widget', () {
    testWidgets('renders item properties and triggers callbacks', (tester) async {
      final item = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Organic Milk',
        category: 'Dairy',
        quantity: 2.0,
        unit: 'bottles',
        expiryDate: DateTime.now().add(const Duration(days: 5)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool recipeGenerated = false;
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PantryItemCard(
              item: item,
              onGenerateRecipe: () => recipeGenerated = true,
              onTap: () => cardTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Organic Milk'), findsOneWidget);
      expect(find.text('2 bottles • Dairy'), findsOneWidget);
      expect(find.byIcon(Icons.kitchen_rounded), findsOneWidget);

      // Tap recipe icon
      await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
      await tester.pump();
      expect(recipeGenerated, isTrue);

      // Tap card
      await tester.tap(find.text('Organic Milk'));
      await tester.pump();
      expect(cardTapped, isTrue);
    });
  });
}
