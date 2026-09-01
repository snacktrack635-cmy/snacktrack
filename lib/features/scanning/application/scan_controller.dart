import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../data/repositories/barcode_repository.dart';
import '../../../data/repositories/subscription_repository.dart';
import '../../../providers/global_providers.dart';

class ScanState {
  final bool isProcessing;
  final String? lastScannedBarcode;
  final BarcodeProductResult? productResult;
  final DateTime? ocrDetectedDate;
  final String? errorMessage;
  final bool isBatchMode;

  const ScanState({
    this.isProcessing = false,
    this.lastScannedBarcode,
    this.productResult,
    this.ocrDetectedDate,
    this.errorMessage,
    this.isBatchMode = false,
  });

  ScanState copyWith({
    bool? isProcessing,
    String? lastScannedBarcode,
    BarcodeProductResult? productResult,
    DateTime? ocrDetectedDate,
    String? errorMessage,
    bool? isBatchMode,
  }) {
    return ScanState(
      isProcessing: isProcessing ?? this.isProcessing,
      lastScannedBarcode: lastScannedBarcode ?? this.lastScannedBarcode,
      productResult: productResult ?? this.productResult,
      ocrDetectedDate: ocrDetectedDate ?? this.ocrDetectedDate,
      errorMessage: errorMessage,
      isBatchMode: isBatchMode ?? this.isBatchMode,
    );
  }
}

class ScanController extends StateNotifier<ScanState> {
  final BarcodeRepository _barcodeRepository;
  final SubscriptionRepository _subscriptionRepository;
  final TextRecognizer _textRecognizer = TextRecognizer();

  ScanController({
    required BarcodeRepository barcodeRepository,
    required SubscriptionRepository subscriptionRepository,
  })  : _barcodeRepository = barcodeRepository,
        _subscriptionRepository = subscriptionRepository,
        super(const ScanState());

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  void toggleBatchMode() {
    state = state.copyWith(isBatchMode: !state.isBatchMode);
  }

  Future<BarcodeProductResult?> processBarcode(String rawBarcode) async {
    if (state.isProcessing || state.lastScannedBarcode == rawBarcode) return null;

    state = state.copyWith(
      isProcessing: true,
      lastScannedBarcode: rawBarcode,
      errorMessage: null,
    );

    try {
      // 1. Quota check
      final sub = await _subscriptionRepository.getSubscription();
      final counters = await _subscriptionRepository.getUsageCounters();
      final canScan = await _subscriptionRepository.canScan(sub.tier, counters.scansUsed);

      if (!canScan) {
        state = state.copyWith(
          isProcessing: false,
          errorMessage: 'Monthly scan quota reached for ${sub.tier.name.toUpperCase()} tier. Please upgrade.',
        );
        return null;
      }

      // 2. Open Food Facts lookup
      final product = await _barcodeRepository.lookupBarcode(rawBarcode);
      await _subscriptionRepository.incrementScanUsage();

      state = state.copyWith(
        isProcessing: false,
        productResult: product,
      );
      return product;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to process barcode: $e',
      );
      return null;
    }
  }

  Future<DateTime?> processOcrImage(String imagePath) async {
    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final date = _extractDateFromText(recognizedText.text);

      state = state.copyWith(
        isProcessing: false,
        ocrDetectedDate: date,
      );
      return date;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'OCR recognition failed: $e',
      );
      return null;
    }
  }

  DateTime? _extractDateFromText(String text) {
    // Regex matches formats: DD/MM/YYYY, YYYY-MM-DD, DD.MM.YY, EXP: MM/YY, etc.
    final dateRegExp = RegExp(
      r'\b(\d{1,2})[/\.-](\d{1,2})[/\.-](\d{2,4})\b|\b(\d{4})[/\.-](\d{1,2})[/\.-](\d{1,2})\b',
    );

    final match = dateRegExp.firstMatch(text);
    if (match != null) {
      try {
        if (match.group(4) != null) {
          // YYYY-MM-DD
          final y = int.parse(match.group(4)!);
          final m = int.parse(match.group(5)!);
          final d = int.parse(match.group(6)!);
          return DateTime(y, m, d);
        } else {
          // DD/MM/YYYY or DD/MM/YY
          final d = int.parse(match.group(1)!);
          final m = int.parse(match.group(2)!);
          var y = int.parse(match.group(3)!);
          if (y < 100) y += 2000;
          return DateTime(y, m, d);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void reset() {
    state = const ScanState();
  }
}

final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  final barcodeRepo = ref.watch(barcodeRepositoryProvider);
  final subRepo = ref.watch(subscriptionRepositoryProvider);
  return ScanController(
    barcodeRepository: barcodeRepo,
    subscriptionRepository: subRepo,
  );
});
