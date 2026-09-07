import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/features/pantry/application/expiry_prediction_controller.dart';

void main() {
  group('ExpiryPredictionController', () {
    late ExpiryPredictionController controller;

    setUp(() {
      controller = ExpiryPredictionController();
    });

    test('initial state has default values', () {
      expect(controller.state.predictedExpiry, isNull);
      expect(controller.state.expirySource, equals('predicted'));
      expect(controller.state.isPredicting, isFalse);
    });

    test('predictFromCategory sets default 14 days when category is null or empty', () {
      controller.predictFromCategory(null);
      expect(controller.state.predictedExpiry, isNotNull);
      expect(controller.state.expirySource, equals('predicted'));

      final days = controller.state.predictedExpiry!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(13, 14));

      controller.predictFromCategory('');
      expect(controller.state.predictedExpiry, isNotNull);
    });

    test('predictFromCategory detects specific categories correctly', () {
      // Dairy (7 days)
      controller.predictFromCategory('Fresh Dairy');
      int days = controller.state.predictedExpiry!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(6, 7));

      // Meat (3 days)
      controller.predictFromCategory('Red Meat');
      days = controller.state.predictedExpiry!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(2, 3));

      // Fish (2 days)
      controller.predictFromCategory('Fresh Fish');
      days = controller.state.predictedExpiry!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(1, 2));

      // Bakery (4-5 days)
      controller.predictFromCategory('Bakery Goods');
      days = controller.state.predictedExpiry!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(3, 4));

      // Canned (365 days)
      controller.predictFromCategory('Canned Goods');
      days = controller.state.predictedExpiry!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(364, 365));
    });

    test('setOcrDetectedDate updates predictedExpiry and marks source as label_ocr', () {
      final date = DateTime(2026, 12, 31);
      controller.setOcrDetectedDate(date);

      expect(controller.state.predictedExpiry, equals(date));
      expect(controller.state.expirySource, equals('label_ocr'));
    });

    test('setManualDate updates predictedExpiry and marks source as manual', () {
      final date = DateTime(2026, 10, 15);
      controller.setManualDate(date);

      expect(controller.state.predictedExpiry, equals(date));
      expect(controller.state.expirySource, equals('manual'));
    });

    test('reset clears state to defaults', () {
      controller.setManualDate(DateTime(2026, 10, 15));
      controller.reset();

      expect(controller.state.predictedExpiry, isNull);
      expect(controller.state.expirySource, equals('predicted'));
    });
  });
}
