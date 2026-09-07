import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/errors/exceptions.dart';
import 'package:snacktrack/core/services/gemini_service.dart';

void main() {
  group('GeminiService', () {
    late GeminiService service;

    setUp(() {
      // Direct offline / standalone instance
      service = GeminiService();
    });

    test('scanFoodItem throws ScanException when no image data is supplied', () async {
      expect(
        () => service.scanFoodItem(),
        throwsA(isA<ScanException>().having(
          (e) => e.message,
          'message',
          contains('Could not read image data'),
        )),
      );
    });

    test('estimateExpiryForFoodName uses category heuristics for dairy (milk)', () async {
      final result = await service.estimateExpiryForFoodName(foodName: 'Whole Milk');

      expect(result.name, equals('Whole Milk'));
      expect(result.category, equals('Dairy'));
      expect(result.daysUntilExpiry, equals(7));
      expect(result.suggestedStorage, equals('refrigerator'));
    });

    test('estimateExpiryForFoodName uses category heuristics for meat (chicken breast)', () async {
      final result = await service.estimateExpiryForFoodName(foodName: 'Chicken Breast');

      expect(result.category, equals('Meat & Seafood'));
      expect(result.daysUntilExpiry, equals(3));
      expect(result.suggestedStorage, equals('pantry'));
    });

    test('estimateExpiryForFoodName uses category heuristics for bakery (sourdough bread)', () async {
      final result = await service.estimateExpiryForFoodName(foodName: 'Sourdough Bread');

      expect(result.category, equals('Bakery'));
      expect(result.daysUntilExpiry, equals(5));
      expect(result.suggestedStorage, equals('pantry'));
    });

    test('estimateExpiryForFoodName uses category heuristics for produce (apples vs bananas)', () async {
      final apples = await service.estimateExpiryForFoodName(foodName: 'Honeycrisp Apple');
      expect(apples.category, equals('Produce'));
      expect(apples.daysUntilExpiry, equals(14));

      final bananas = await service.estimateExpiryForFoodName(foodName: 'Ripe Banana');
      expect(bananas.category, equals('Produce'));
      expect(bananas.daysUntilExpiry, equals(4));
    });

    test('estimateExpiryForFoodName uses category heuristics for dry pantry staples (rice)', () async {
      final rice = await service.estimateExpiryForFoodName(foodName: 'White Rice');
      expect(rice.category, equals('Pantry'));
      expect(rice.daysUntilExpiry, equals(365));
      expect(rice.suggestedStorage, equals('pantry'));
    });

    test('estimateExpiryForFoodName handles unknown foods with sensible default', () async {
      final mystery = await service.estimateExpiryForFoodName(foodName: 'Mystery Snack');
      expect(mystery.daysUntilExpiry, equals(7));
      expect(mystery.suggestedStorage, equals('refrigerator'));
    });
  });
}
