import 'package:flutter_test/flutter_test.dart';
import 'package:pos_inventory_system/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('Product creation from map works correctly', () {
      final map = {
        'id': 'test-id',
        'name': 'Test Product',
        'barcode': '123456789',
        'price': 99.99,
        'category': 'Electronics',
        'description': 'A test product',
        'stockQuantity': 10,
        'minStockLevel': 5,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final product = Product.fromMap(map);

      expect(product.id, equals('test-id'));
      expect(product.name, equals('Test Product'));
      expect(product.barcode, equals('123456789'));
      expect(product.price, equals(99.99));
      expect(product.category, equals('Electronics'));
      expect(product.description, equals('A test product'));
      expect(product.stockQuantity, equals(10));
      expect(product.minStockLevel, equals(5));
    });

    test('Product toMap() works correctly', () {
      final now = DateTime.now();
      final product = Product(
        id: 'test-id',
        name: 'Test Product',
        barcode: '123456789',
        price: 99.99,
        category: 'Electronics',
        description: 'A test product',
        stockQuantity: 10,
        minStockLevel: 5,
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toMap();

      expect(map['id'], equals('test-id'));
      expect(map['name'], equals('Test Product'));
      expect(map['barcode'], equals('123456789'));
      expect(map['price'], equals(99.99));
      expect(map['category'], equals('Electronics'));
      expect(map['description'], equals('A test product'));
      expect(map['stockQuantity'], equals(10));
      expect(map['minStockLevel'], equals(5));
    });

    test('Product isLowStock works correctly', () {
      final now = DateTime.now();
      final lowStockProduct = Product(
        id: 'test-id',
        name: 'Test Product',
        barcode: '123456789',
        price: 99.99,
        category: 'Electronics',
        description: 'A test product',
        stockQuantity: 3,
        minStockLevel: 5,
        createdAt: now,
        updatedAt: now,
      );

      final normalStockProduct = Product(
        id: 'test-id-2',
        name: 'Test Product 2',
        barcode: '987654321',
        price: 49.99,
        category: 'Electronics',
        description: 'Another test product',
        stockQuantity: 10,
        minStockLevel: 5,
        createdAt: now,
        updatedAt: now,
      );

      expect(lowStockProduct.isLowStock, isTrue);
      expect(normalStockProduct.isLowStock, isFalse);
    });

    test('Product isOutOfStock works correctly', () {
      final now = DateTime.now();
      final outOfStockProduct = Product(
        id: 'test-id',
        name: 'Test Product',
        barcode: '123456789',
        price: 99.99,
        category: 'Electronics',
        description: 'A test product',
        stockQuantity: 0,
        minStockLevel: 5,
        createdAt: now,
        updatedAt: now,
      );

      final inStockProduct = Product(
        id: 'test-id-2',
        name: 'Test Product 2',
        barcode: '987654321',
        price: 49.99,
        category: 'Electronics',
        description: 'Another test product',
        stockQuantity: 10,
        minStockLevel: 5,
        createdAt: now,
        updatedAt: now,
      );

      expect(outOfStockProduct.isOutOfStock, isTrue);
      expect(inStockProduct.isOutOfStock, isFalse);
    });
  });
}
