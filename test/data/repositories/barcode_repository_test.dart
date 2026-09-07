import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/data/repositories/barcode_repository.dart';

void main() {
  group('BarcodeRepository & BarcodeProductResult', () {
    test('BarcodeProductResult holds product metadata properly', () {
      const result = BarcodeProductResult(
        barcode: '9300601234567',
        name: 'Whole Grain Oats',
        category: 'Breakfast Cereals',
        imageUrl: 'https://images.openfoodfacts.org/oats.jpg',
        brand: 'Uncle Tobys',
      );

      expect(result.barcode, equals('9300601234567'));
      expect(result.name, equals('Whole Grain Oats'));
      expect(result.category, equals('Breakfast Cereals'));
      expect(result.imageUrl, equals('https://images.openfoodfacts.org/oats.jpg'));
      expect(result.brand, equals('Uncle Tobys'));
    });

    test('lookupBarcode gracefully returns null on network exception or invalid barcode', () async {
      // In offline/test environment without mocking low-level HttpClient,
      // invalid URL host resolution throws and repository returns null
      final repository = BarcodeRepository();
      final result = await repository.lookupBarcode('invalid_barcode_xyz_123');
      expect(result, isNull);
    });
  });
}
