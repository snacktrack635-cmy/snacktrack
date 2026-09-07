import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/models/ai_food_scan_result.dart';

void main() {
  group('AiFoodScanResult', () {
    test('fromJson parses complete valid JSON payload', () {
      final json = {
        'name': 'Organic Avocado',
        'category': 'Produce',
        'days_until_expiry': 4,
        'estimated_expiry_date': '2026-09-11T12:00:00.000Z',
        'confidence': 0.96,
        'freshness_notes': 'Firm skin, ready to eat in 2 days',
        'suggested_storage': 'refrigerator',
        'estimated_quantity': 3.0,
        'estimated_unit': 'pcs',
      };

      final result = AiFoodScanResult.fromJson(json, imagePath: '/path/to/img.jpg');

      expect(result.name, equals('Organic Avocado'));
      expect(result.category, equals('Produce'));
      expect(result.daysUntilExpiry, equals(4));
      expect(result.confidence, equals(0.96));
      expect(result.freshnessNotes, equals('Firm skin, ready to eat in 2 days'));
      expect(result.suggestedStorage, equals('refrigerator'));
      expect(result.estimatedQuantity, equals(3.0));
      expect(result.estimatedUnit, equals('pcs'));
      expect(result.imagePath, equals('/path/to/img.jpg'));
    });

    test('fromJson handles missing fields and falls back gracefully', () {
      final json = <String, dynamic>{};
      final result = AiFoodScanResult.fromJson(json);

      expect(result.name, equals('Identified Food Item'));
      expect(result.category, isNull);
      expect(result.daysUntilExpiry, equals(7)); // default 7 days
      expect(result.confidence, equals(1.0));
      expect(result.estimatedQuantity, equals(1.0));
      expect(result.estimatedUnit, equals('pcs'));
      expect(result.imagePath, isNull);
    });

    test('fromJson parses shelf_life_days when days_until_expiry is absent', () {
      final json = {
        'name': 'Cheddar Block',
        'shelf_life_days': 21,
      };
      final result = AiFoodScanResult.fromJson(json);
      expect(result.daysUntilExpiry, equals(21));
    });

    test('fromJson gracefully recovers when estimated_expiry_date is unparseable', () {
      final json = {
        'name': 'Milk',
        'days_until_expiry': 5,
        'estimated_expiry_date': 'not-a-valid-date',
      };
      final result = AiFoodScanResult.fromJson(json);
      expect(result.name, equals('Milk'));
      expect(result.daysUntilExpiry, equals(5));
      expect(result.estimatedExpiryDate, isNotNull);
    });

    test('toJson serializes all fields correctly', () {
      final now = DateTime(2026, 9, 15);
      final model = AiFoodScanResult(
        name: 'Whole Milk',
        category: 'Dairy',
        estimatedExpiryDate: now,
        daysUntilExpiry: 6,
        confidence: 0.99,
        freshnessNotes: 'Sealed carton',
        suggestedStorage: 'refrigerator',
        estimatedQuantity: 1.0,
        estimatedUnit: 'carton',
        imagePath: '/tmp/milk.jpg',
      );

      final json = model.toJson();
      expect(json['name'], equals('Whole Milk'));
      expect(json['category'], equals('Dairy'));
      expect(json['estimated_expiry_date'], equals(now.toIso8601String()));
      expect(json['days_until_expiry'], equals(6));
      expect(json['confidence'], equals(0.99));
      expect(json['freshness_notes'], equals('Sealed carton'));
      expect(json['suggested_storage'], equals('refrigerator'));
      expect(json['estimated_quantity'], equals(1.0));
      expect(json['estimated_unit'], equals('carton'));
      expect(json['image_path'], equals('/tmp/milk.jpg'));
    });

    test('toItemScanExtra returns valid map for route extras', () {
      final now = DateTime(2026, 9, 15);
      final model = AiFoodScanResult(
        name: 'Tomato',
        category: 'Produce',
        estimatedExpiryDate: now,
        daysUntilExpiry: 5,
        confidence: 0.9,
        freshnessNotes: 'Ripe red',
        suggestedStorage: 'refrigerator',
        estimatedQuantity: 4.0,
        estimatedUnit: 'pcs',
        imagePath: '/tmp/tomato.jpg',
      );

      final extra = model.toItemScanExtra();
      expect(extra['name'], equals('Tomato'));
      expect(extra['category'], equals('Produce'));
      expect(extra['expiryDate'], equals(now));
      expect(extra['expirySource'], equals('ai_predicted'));
      expect(extra['quantity'], equals(4.0));
      expect(extra['unit'], equals('pcs'));
      expect(extra['freshnessNotes'], equals('Ripe red'));
      expect(extra['suggestedStorage'], equals('refrigerator'));
      expect(extra['imageUrl'], equals('/tmp/tomato.jpg'));
    });

    test('toPantryItem converts into a PantryItem instance', () {
      final now = DateTime(2026, 9, 15);
      final model = AiFoodScanResult(
        name: 'Greek Yogurt',
        category: 'Dairy',
        estimatedExpiryDate: now,
        daysUntilExpiry: 12,
        confidence: 0.98,
        estimatedQuantity: 1.0,
        estimatedUnit: 'tub',
        imagePath: '/tmp/yogurt.jpg',
      );

      final pantryItem = model.toPantryItem(
        id: 'p-1',
        userId: 'u-1',
        barcode: '123456789',
      );

      expect(pantryItem.id, equals('p-1'));
      expect(pantryItem.userId, equals('u-1'));
      expect(pantryItem.barcode, equals('123456789'));
      expect(pantryItem.name, equals('Greek Yogurt'));
      expect(pantryItem.category, equals('Dairy'));
      expect(pantryItem.quantity, equals(1.0));
      expect(pantryItem.unit, equals('tub'));
      expect(pantryItem.expiryDate, equals(now));
      expect(pantryItem.expirySource, equals('ai_predicted'));
      expect(pantryItem.imageUrl, equals('/tmp/yogurt.jpg'));
    });
  });
}
