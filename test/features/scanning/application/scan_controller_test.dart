import 'package:flutter_test/flutter_test.dart';
import 'package:snacktrack/core/constants/tier_limits.dart';
import 'package:snacktrack/data/models/ai_food_scan_result.dart';
import 'package:snacktrack/data/models/subscription.dart';
import 'package:snacktrack/data/repositories/barcode_repository.dart';
import 'package:snacktrack/features/scanning/application/scan_controller.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('ScanController', () {
    late FakeBarcodeRepository barcodeRepo;
    late FakeSubscriptionRepository subRepo;
    late FakeGeminiService geminiService;
    late ScanController controller;

    setUp(() {
      barcodeRepo = FakeBarcodeRepository();
      subRepo = FakeSubscriptionRepository();
      geminiService = FakeGeminiService();
      controller = ScanController(
        barcodeRepository: barcodeRepo,
        subscriptionRepository: subRepo,
        geminiService: geminiService,
      );
    });

    test('initial state has correct defaults', () {
      expect(controller.state.isProcessing, isFalse);
      expect(controller.state.isBatchMode, isFalse);
      expect(controller.state.lastScannedBarcode, isNull);
      expect(controller.state.productResult, isNull);
      expect(controller.state.aiScanResult, isNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('toggleBatchMode flips isBatchMode flag', () {
      controller.toggleBatchMode();
      expect(controller.state.isBatchMode, isTrue);
      controller.toggleBatchMode();
      expect(controller.state.isBatchMode, isFalse);
    });

    test('processBarcode ignores immediate duplicate scan of same barcode', () async {
      barcodeRepo.productToReturn = const BarcodeProductResult(
        barcode: '123456',
        name: 'Orange Juice',
      );

      final firstScan = await controller.processBarcode('123456');
      expect(firstScan, isNotNull);
      expect(controller.state.lastScannedBarcode, equals('123456'));

      // Second scan with identical barcode should return null immediately
      final duplicateScan = await controller.processBarcode('123456');
      expect(duplicateScan, isNull);
    });

    test('processBarcode halts and sets error when monthly scan quota is reached', () async {
      subRepo.canScanResult = false;
      subRepo.subscription = UserSubscription(
        id: 's-1',
        userId: 'u-1',
        tier: SubscriptionTier.free,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await controller.processBarcode('987654');

      expect(result, isNull);
      expect(controller.state.isProcessing, isFalse);
      expect(controller.state.errorMessage, contains('Monthly scan quota reached'));
      expect(subRepo.incrementScanUsageCalls, equals(0));
    });

    test('processBarcode succeeds and increments scan count', () async {
      subRepo.canScanResult = true;
      barcodeRepo.productToReturn = const BarcodeProductResult(
        barcode: '111222',
        name: 'Whole Grain Cereal',
        category: 'Breakfast',
      );

      final result = await controller.processBarcode('111222');

      expect(result, isNotNull);
      expect(result!.name, equals('Whole Grain Cereal'));
      expect(controller.state.productResult, equals(result));
      expect(controller.state.errorMessage, isNull);
      expect(subRepo.incrementScanUsageCalls, equals(1));
    });

    test('processBarcode sets errorMessage when repository throws exception', () async {
      subRepo.canScanResult = true;
      barcodeRepo.throwOnError = true;
      barcodeRepo.errorMessage = 'Network connection dropped';

      final result = await controller.processBarcode('333444');

      expect(result, isNull);
      expect(controller.state.isProcessing, isFalse);
      expect(controller.state.errorMessage, contains('Failed to process barcode'));
    });

    test('processAiFoodScan stops and sets error when quota exceeded', () async {
      subRepo.canScanResult = false;

      final result = await controller.processAiFoodScan();

      expect(result, isNull);
      expect(controller.state.isProcessing, isFalse);
      expect(controller.state.errorMessage, contains('Monthly scan quota reached'));
    });

    test('processAiFoodScan succeeds with Gemini multimodal result', () async {
      subRepo.canScanResult = true;
      final scanOutput = AiFoodScanResult(
        name: 'Strawberries',
        category: 'Produce',
        estimatedExpiryDate: DateTime.now().add(const Duration(days: 4)),
        daysUntilExpiry: 4,
      );
      geminiService.scanResult = scanOutput;

      final result = await controller.processAiFoodScan();

      expect(result, isNotNull);
      expect(result!.name, equals('Strawberries'));
      expect(controller.state.aiScanResult, equals(result));
      expect(subRepo.incrementScanUsageCalls, equals(1));
      expect(controller.state.errorMessage, isNull);
    });

    test('processAiFoodScan handles AI processing failures gracefully', () async {
      subRepo.canScanResult = true;
      geminiService.throwScanException = true;
      geminiService.errorMessage = 'Image resolution too low';

      final result = await controller.processAiFoodScan();

      expect(result, isNull);
      expect(controller.state.isProcessing, isFalse);
      expect(controller.state.errorMessage, contains('AI food scanning failed'));
    });

    test('reset clears scan state back to defaults', () async {
      controller.toggleBatchMode();
      subRepo.canScanResult = true;
      barcodeRepo.productToReturn = const BarcodeProductResult(barcode: '123', name: 'Item');
      await controller.processBarcode('123');

      expect(controller.state.lastScannedBarcode, equals('123'));

      controller.reset();

      expect(controller.state.lastScannedBarcode, isNull);
      expect(controller.state.productResult, isNull);
      expect(controller.state.isBatchMode, isFalse);
    });
  });
}
