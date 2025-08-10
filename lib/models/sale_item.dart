class SaleItem {
  final String id;
  final String productId;
  final String productName;
  final String productBarcode;
  final double unitPrice;
  final int quantity;
  final double totalPrice;

  SaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productBarcode,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  // Convert SaleItem to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productBarcode': productBarcode,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'totalPrice': totalPrice,
    };
  }

  // Create SaleItem from Map (database retrieval)
  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      productId: map['productId'],
      productName: map['productName'],
      productBarcode: map['productBarcode'],
      unitPrice: map['unitPrice'].toDouble(),
      quantity: map['quantity'],
      totalPrice: map['totalPrice'].toDouble(),
    );
  }

  // Create a copy of SaleItem with updated fields
  SaleItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productBarcode,
    double? unitPrice,
    int? quantity,
    double? totalPrice,
  }) {
    return SaleItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  @override
  String toString() {
    return 'SaleItem{id: $id, productName: $productName, quantity: $quantity, totalPrice: $totalPrice}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Sale {
  final String id;
  final List<SaleItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final DateTime timestamp;
  final String? customerName;
  final String paymentMethod;

  Sale({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.timestamp,
    this.customerName,
    required this.paymentMethod,
  });

  // Convert Sale to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'customerName': customerName,
      'paymentMethod': paymentMethod,
    };
  }

  // Create Sale from Map (database retrieval)
  factory Sale.fromMap(Map<String, dynamic> map, List<SaleItem> items) {
    return Sale(
      id: map['id'],
      items: items,
      subtotal: map['subtotal'].toDouble(),
      tax: map['tax'].toDouble(),
      total: map['total'].toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      customerName: map['customerName'],
      paymentMethod: map['paymentMethod'],
    );
  }

  @override
  String toString() {
    return 'Sale{id: $id, total: $total, timestamp: $timestamp, itemsCount: ${items.length}}';
  }
}
