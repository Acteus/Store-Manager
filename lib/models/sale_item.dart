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
  final bool isVoided;
  final DateTime? voidedAt;
  final String? voidReason;

  Sale({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.timestamp,
    this.customerName,
    required this.paymentMethod,
    this.isVoided = false,
    this.voidedAt,
    this.voidReason,
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
      'isVoided': isVoided ? 1 : 0,
      'voidedAt': voidedAt?.millisecondsSinceEpoch,
      'voidReason': voidReason,
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
      isVoided: (map['isVoided'] ?? 0) == 1,
      voidedAt: map['voidedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['voidedAt'])
          : null,
      voidReason: map['voidReason'],
    );
  }

  // Create a copy of Sale with updated fields (for voiding)
  Sale copyWith({
    String? id,
    List<SaleItem>? items,
    double? subtotal,
    double? tax,
    double? total,
    DateTime? timestamp,
    String? customerName,
    String? paymentMethod,
    bool? isVoided,
    DateTime? voidedAt,
    String? voidReason,
  }) {
    return Sale(
      id: id ?? this.id,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      timestamp: timestamp ?? this.timestamp,
      customerName: customerName ?? this.customerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isVoided: isVoided ?? this.isVoided,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
    );
  }

  @override
  String toString() {
    return 'Sale{id: $id, total: $total, timestamp: $timestamp, itemsCount: ${items.length}}';
  }
}
