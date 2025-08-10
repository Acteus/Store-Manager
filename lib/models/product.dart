class Product {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final String category;
  final String? description;
  final int stockQuantity;
  final int minStockLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.category,
    this.description,
    required this.stockQuantity,
    this.minStockLevel = 5,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert Product to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'category': category,
      'description': description,
      'stockQuantity': stockQuantity,
      'minStockLevel': minStockLevel,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create Product from Map (database retrieval)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: map['price'].toDouble(),
      category: map['category'],
      description: map['description'],
      stockQuantity: map['stockQuantity'],
      minStockLevel: map['minStockLevel'] ?? 5,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
    );
  }

  // Create a copy of Product with updated fields
  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    String? category,
    String? description,
    int? stockQuantity,
    int? minStockLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      category: category ?? this.category,
      description: description ?? this.description,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Check if product is low in stock
  bool get isLowStock => stockQuantity <= minStockLevel;

  // Check if product is out of stock
  bool get isOutOfStock => stockQuantity <= 0;

  @override
  String toString() {
    return 'Product{id: $id, name: $name, barcode: $barcode, price: $price, stockQuantity: $stockQuantity}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
