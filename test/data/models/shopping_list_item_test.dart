import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/shopping_list_item.dart';

void main() {
  group('ShoppingListItem', () {
    test('fromJson parses complete valid JSON payload', () {
      final json = {
        'id': 'item-10',
        'user_id': 'u-20',
        'name': 'Olive Oil',
        'quantity': 2.0,
        'unit': 'bottle',
        'is_checked': true,
        'source': 'recipe',
        'created_at': '2026-09-01T15:30:00.000Z',
      };

      final item = ShoppingListItem.fromJson(json);

      expect(item.id, equals('item-10'));
      expect(item.userId, equals('u-20'));
      expect(item.name, equals('Olive Oil'));
      expect(item.quantity, equals(2.0));
      expect(item.unit, equals('bottle'));
      expect(item.isChecked, isTrue);
      expect(item.source, equals('recipe'));
      expect(item.createdAt, equals(DateTime.parse('2026-09-01T15:30:00.000Z')));
    });

    test('fromJson falls back to defaults for optional fields', () {
      final json = {
        'id': 'item-1',
        'user_id': 'u-1',
        'name': 'Butter',
      };

      final item = ShoppingListItem.fromJson(json);

      expect(item.quantity, equals(1.0));
      expect(item.unit, isNull);
      expect(item.isChecked, isFalse);
      expect(item.source, equals('manual'));
      expect(item.createdAt, isNotNull);
    });

    test('toJson serializes correctly', () {
      final now = DateTime(2026, 9, 5);
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Apples',
        quantity: 6.0,
        unit: 'pcs',
        isChecked: false,
        source: 'manual',
        createdAt: now,
      );

      final json = item.toJson();

      expect(json['id'], equals('i-1'));
      expect(json['user_id'], equals('u-1'));
      expect(json['name'], equals('Apples'));
      expect(json['quantity'], equals(6.0));
      expect(json['unit'], equals('pcs'));
      expect(json['is_checked'], isFalse);
      expect(json['source'], equals('manual'));
      expect(json['created_at'], equals(now.toIso8601String()));
    });

    test('copyWith updates specified fields and preserves others', () {
      final item = ShoppingListItem(
        id: 'i-1',
        userId: 'u-1',
        name: 'Bread',
        quantity: 1.0,
        isChecked: false,
        createdAt: DateTime.now(),
      );

      final updated = item.copyWith(isChecked: true, quantity: 2.0);

      expect(updated.id, equals('i-1'));
      expect(updated.name, equals('Bread'));
      expect(updated.quantity, equals(2.0));
      expect(updated.isChecked, isTrue);
    });
  });
}
