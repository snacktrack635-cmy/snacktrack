class ShoppingListItem {
  final String id;
  final String userId;
  final String name;
  final double quantity;
  final String? unit;
  final bool isChecked;
  final String source; // manual | recipe | low_stock
  final DateTime createdAt;

  const ShoppingListItem({
    required this.id,
    required this.userId,
    required this.name,
    this.quantity = 1.0,
    this.unit,
    this.isChecked = false,
    this.source = 'manual',
    required this.createdAt,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String?,
      isChecked: json['is_checked'] as bool? ?? false,
      source: json['source'] as String? ?? 'manual',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'is_checked': isChecked,
      'source': source,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ShoppingListItem copyWith({
    String? id,
    String? userId,
    String? name,
    double? quantity,
    String? unit,
    bool? isChecked,
    String? source,
    DateTime? createdAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
