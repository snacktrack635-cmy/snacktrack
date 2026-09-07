import '../models/pantry_item.dart';

/// Represents the output of a Gemini multimodal vision scan on a food item.
class AiFoodScanResult {
  final String name;
  final String? category;
  final DateTime estimatedExpiryDate;
  final int daysUntilExpiry;
  final double confidence;
  final String? freshnessNotes;
  final String? suggestedStorage;
  final double? estimatedQuantity;
  final String? estimatedUnit;
  final String? imagePath;
  final Map<String, dynamic>? rawResponse;

  const AiFoodScanResult({
    required this.name,
    this.category,
    required this.estimatedExpiryDate,
    required this.daysUntilExpiry,
    this.confidence = 1.0,
    this.freshnessNotes,
    this.suggestedStorage,
    this.estimatedQuantity,
    this.estimatedUnit,
    this.imagePath,
    this.rawResponse,
  });

  factory AiFoodScanResult.fromJson(Map<String, dynamic> json, {String? imagePath}) {
    final now = DateTime.now();
    int days = 7;
    if (json['days_until_expiry'] != null) {
      days = (json['days_until_expiry'] as num).toInt();
    } else if (json['shelf_life_days'] != null) {
      days = (json['shelf_life_days'] as num).toInt();
    }

    DateTime calculatedDate;
    if (json['estimated_expiry_date'] != null) {
      try {
        calculatedDate = DateTime.parse(json['estimated_expiry_date'] as String);
      } catch (_) {
        calculatedDate = DateTime(now.year, now.month, now.day).add(Duration(days: days));
      }
    } else {
      calculatedDate = DateTime(now.year, now.month, now.day).add(Duration(days: days));
    }

    return AiFoodScanResult(
      name: json['name'] as String? ?? 'Identified Food Item',
      category: json['category'] as String?,
      estimatedExpiryDate: calculatedDate,
      daysUntilExpiry: days,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      freshnessNotes: json['freshness_notes'] as String?,
      suggestedStorage: json['suggested_storage'] as String?,
      estimatedQuantity: (json['estimated_quantity'] as num?)?.toDouble() ?? 1.0,
      estimatedUnit: json['estimated_unit'] as String? ?? 'pcs',
      imagePath: imagePath,
      rawResponse: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'estimated_expiry_date': estimatedExpiryDate.toIso8601String(),
      'days_until_expiry': daysUntilExpiry,
      'confidence': confidence,
      'freshness_notes': freshnessNotes,
      'suggested_storage': suggestedStorage,
      'estimated_quantity': estimatedQuantity,
      'estimated_unit': estimatedUnit,
      if (imagePath != null) 'image_path': imagePath,
    };
  }

  /// Converts this result into route arguments for `/pantry/item-scan`
  /// so the user can review and manually edit all fields before saving.
  Map<String, dynamic> toItemScanExtra() {
    return {
      'name': name,
      'category': category,
      'expiryDate': estimatedExpiryDate,
      'expirySource': 'ai_predicted',
      'quantity': estimatedQuantity ?? 1.0,
      'unit': estimatedUnit ?? 'pcs',
      'freshnessNotes': freshnessNotes,
      'suggestedStorage': suggestedStorage,
      'imageUrl': imagePath,
    };
  }

  /// Converts directly into a [PantryItem]
  PantryItem toPantryItem({
    String id = '',
    String userId = '',
    String? barcode,
  }) {
    final now = DateTime.now();
    return PantryItem(
      id: id,
      userId: userId,
      name: name,
      barcode: barcode,
      category: category,
      quantity: estimatedQuantity ?? 1.0,
      unit: estimatedUnit ?? 'pcs',
      expiryDate: estimatedExpiryDate,
      expirySource: 'ai_predicted',
      imageUrl: imagePath,
      createdAt: now,
      updatedAt: now,
    );
  }
}
