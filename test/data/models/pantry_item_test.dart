import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/pantry_item.dart';

void main() {
  group('PantryItem', () {
    test('fromJson parses complete valid JSON payload', () {
      final json = {
        'id': 'p-123',
        'user_id': 'u-456',
        'name': 'Almond Milk',
        'normalized_name': 'almond milk',
        'barcode': '93100555',
        'category': 'Dairy',
        'quantity': 2.5,
        'unit': 'L',
        'expiry_date': '2026-10-15T00:00:00.000Z',
        'expiry_source': 'manual',
        'image_url': 'https://example.com/almond.jpg',
        'created_at': '2026-09-01T10:00:00.000Z',
        'updated_at': '2026-09-02T12:00:00.000Z',
      };

      final item = PantryItem.fromJson(json);

      expect(item.id, equals('p-123'));
      expect(item.userId, equals('u-456'));
      expect(item.name, equals('Almond Milk'));
      expect(item.normalizedName, equals('almond milk'));
      expect(item.barcode, equals('93100555'));
      expect(item.category, equals('Dairy'));
      expect(item.quantity, equals(2.5));
      expect(item.unit, equals('L'));
      expect(item.expiryDate, equals(DateTime.parse('2026-10-15T00:00:00.000Z')));
      expect(item.expirySource, equals('manual'));
      expect(item.imageUrl, equals('https://example.com/almond.jpg'));
    });

    test('fromJson provides sensible defaults for optional fields', () {
      final json = {
        'id': 'p-999',
        'user_id': 'u-999',
        'name': 'Bread',
      };

      final item = PantryItem.fromJson(json);

      expect(item.quantity, equals(1.0));
      expect(item.unit, isNull);
      expect(item.expiryDate, isNull);
      expect(item.expirySource, equals('predicted'));
      expect(item.barcode, isNull);
      expect(item.imageUrl, isNull);
      expect(item.createdAt, isNotNull);
      expect(item.updatedAt, isNotNull);
    });

    test('toJson serializes correctly with formatted expiry_date', () {
      final item = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Eggs',
        normalizedName: 'eggs',
        barcode: '112233',
        category: 'Dairy',
        quantity: 12.0,
        unit: 'pcs',
        expiryDate: DateTime(2026, 9, 25),
        expirySource: 'predicted',
        imageUrl: 'http://img.png',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 2),
      );

      final json = item.toJson();

      expect(json['id'], equals('p-1'));
      expect(json['user_id'], equals('u-1'));
      expect(json['name'], equals('Eggs'));
      expect(json['normalized_name'], equals('eggs'));
      expect(json['barcode'], equals('112233'));
      expect(json['category'], equals('Dairy'));
      expect(json['quantity'], equals(12.0));
      expect(json['unit'], equals('pcs'));
      expect(json['expiry_date'], equals('2026-09-25'));
      expect(json['expiry_source'], equals('predicted'));
      expect(json['image_url'], equals('http://img.png'));
    });

    test('toJson produces null expiry_date when expiryDate is null', () {
      final item = PantryItem(
        id: 'p-2',
        userId: 'u-1',
        name: 'Salt',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = item.toJson();
      expect(json['expiry_date'], isNull);
    });

    test('copyWith updates specified fields and preserves others', () {
      final original = PantryItem(
        id: 'p-1',
        userId: 'u-1',
        name: 'Pasta',
        quantity: 1.0,
        unit: 'box',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(
        quantity: 3.0,
        name: 'Whole Wheat Pasta',
      );

      expect(updated.id, equals('p-1'));
      expect(updated.userId, equals('u-1'));
      expect(updated.name, equals('Whole Wheat Pasta'));
      expect(updated.quantity, equals(3.0));
      expect(updated.unit, equals('box'));
    });
  });
}
