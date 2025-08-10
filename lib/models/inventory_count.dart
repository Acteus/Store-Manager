class InventoryCount {
  final String id;
  final String productId;
  final String productName;
  final String productBarcode;
  final int systemCount;
  final int physicalCount;
  final int variance;
  final DateTime countDate;
  final String? notes;
  final String countedBy;

  InventoryCount({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productBarcode,
    required this.systemCount,
    required this.physicalCount,
    required this.variance,
    required this.countDate,
    this.notes,
    required this.countedBy,
  });

  // Convert InventoryCount to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productBarcode': productBarcode,
      'systemCount': systemCount,
      'physicalCount': physicalCount,
      'variance': variance,
      'countDate': countDate.millisecondsSinceEpoch,
      'notes': notes,
      'countedBy': countedBy,
    };
  }

  // Create InventoryCount from Map (database retrieval)
  factory InventoryCount.fromMap(Map<String, dynamic> map) {
    return InventoryCount(
      id: map['id'],
      productId: map['productId'],
      productName: map['productName'],
      productBarcode: map['productBarcode'],
      systemCount: map['systemCount'],
      physicalCount: map['physicalCount'],
      variance: map['variance'],
      countDate: DateTime.fromMillisecondsSinceEpoch(map['countDate']),
      notes: map['notes'],
      countedBy: map['countedBy'],
    );
  }

  // Create a copy of InventoryCount with updated fields
  InventoryCount copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productBarcode,
    int? systemCount,
    int? physicalCount,
    int? variance,
    DateTime? countDate,
    String? notes,
    String? countedBy,
  }) {
    return InventoryCount(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      systemCount: systemCount ?? this.systemCount,
      physicalCount: physicalCount ?? this.physicalCount,
      variance: variance ?? this.variance,
      countDate: countDate ?? this.countDate,
      notes: notes ?? this.notes,
      countedBy: countedBy ?? this.countedBy,
    );
  }

  // Check if there's a significant variance
  bool get hasVariance => variance != 0;

  // Check if variance is positive (overstock)
  bool get isOverstock => variance > 0;

  // Check if variance is negative (shortage)
  bool get isShortage => variance < 0;

  @override
  String toString() {
    return 'InventoryCount{id: $id, productName: $productName, systemCount: $systemCount, physicalCount: $physicalCount, variance: $variance}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryCount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
