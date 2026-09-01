class PantryItem {
  final String id;
  final String userId;
  final String name;
  final String? normalizedName;
  final String? barcode;
  final String? category;
  final double quantity;
  final String? unit;
  final DateTime? expiryDate;
  final String expirySource; // predicted | manual | label_ocr
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PantryItem({
    required this.id,
    required this.userId,
    required this.name,
    this.normalizedName,
    this.barcode,
    this.category,
    this.quantity = 1.0,
    this.unit,
    this.expiryDate,
    this.expirySource = 'predicted',
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      normalizedName: json['normalized_name'] as String?,
      barcode: json['barcode'] as String?,
      category: json['category'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      expirySource: json['expiry_source'] as String? ?? 'predicted',
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      'barcode': barcode,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'expiry_date': expiryDate != null
          ? '${expiryDate!.year.toString().padLeft(4, '0')}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}'
          : null,
      'expiry_source': expirySource,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PantryItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? normalizedName,
    String? barcode,
    String? category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    String? expirySource,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PantryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      expirySource: expirySource ?? this.expirySource,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
