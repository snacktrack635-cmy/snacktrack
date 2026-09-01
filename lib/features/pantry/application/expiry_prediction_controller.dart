import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpiryPredictionState {
  final DateTime? predictedExpiry;
  final String expirySource; // 'predicted' | 'label_ocr' | 'manual'
  final bool isPredicting;

  const ExpiryPredictionState({
    this.predictedExpiry,
    this.expirySource = 'predicted',
    this.isPredicting = false,
  });

  ExpiryPredictionState copyWith({
    DateTime? predictedExpiry,
    String? expirySource,
    bool? isPredicting,
  }) {
    return ExpiryPredictionState(
      predictedExpiry: predictedExpiry ?? this.predictedExpiry,
      expirySource: expirySource ?? this.expirySource,
      isPredicting: isPredicting ?? this.isPredicting,
    );
  }
}

class ExpiryPredictionController extends StateNotifier<ExpiryPredictionState> {
  ExpiryPredictionController() : super(const ExpiryPredictionState());

  static const Map<String, int> _categoryHeuristicDays = {
    'dairy': 7,
    'milk': 7,
    'meat': 3,
    'poultry': 3,
    'fish': 2,
    'seafood': 2,
    'produce': 5,
    'fruits': 7,
    'vegetables': 5,
    'bakery': 4,
    'bread': 5,
    'canned': 365,
    'canned goods': 365,
    'pantry': 180,
    'pasta': 365,
    'rice': 365,
    'snacks': 90,
    'beverages': 30,
    'frozen': 90,
    'condiments': 180,
  };

  void predictFromCategory(String? category) {
    if (category == null || category.isEmpty) {
      final defaultDate = DateTime.now().add(const Duration(days: 14));
      state = state.copyWith(
        predictedExpiry: defaultDate,
        expirySource: 'predicted',
      );
      return;
    }

    final lower = category.toLowerCase().trim();
    int days = 14; // Default fallback

    for (final entry in _categoryHeuristicDays.entries) {
      if (lower.contains(entry.key)) {
        days = entry.value;
        break;
      }
    }

    state = state.copyWith(
      predictedExpiry: DateTime.now().add(Duration(days: days)),
      expirySource: 'predicted',
    );
  }

  void setOcrDetectedDate(DateTime date) {
    state = state.copyWith(
      predictedExpiry: date,
      expirySource: 'label_ocr',
    );
  }

  void setManualDate(DateTime date) {
    state = state.copyWith(
      predictedExpiry: date,
      expirySource: 'manual',
    );
  }

  void reset() {
    state = const ExpiryPredictionState();
  }
}

final expiryPredictionControllerProvider =
    StateNotifierProvider<ExpiryPredictionController, ExpiryPredictionState>((ref) {
  return ExpiryPredictionController();
});
