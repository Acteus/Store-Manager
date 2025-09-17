import 'package:flutter/material.dart';
import '../models/product.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<ProductLowStockNotification> _activeNotifications = [];

  /// Show low stock notification
  void showLowStockNotification(BuildContext context, Product product) {
    // Check if notification already exists for this product
    if (_activeNotifications.any((n) => n.productId == product.id)) {
      return;
    }

    final notification = ProductLowStockNotification(
      productId: product.id,
      productName: product.name,
      currentStock: product.stockQuantity,
      minStockLevel: product.minStockLevel,
      timestamp: DateTime.now(),
    );

    _activeNotifications.add(notification);

    // Show snackbar notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Low Stock Alert',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${product.name}: ${product.stockQuantity} left (min: ${product.minStockLevel})',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/inventory');
          },
        ),
      ),
    );
  }

  /// Show out of stock notification
  void showOutOfStockNotification(BuildContext context, Product product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Out of Stock',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${product.name} is out of stock!',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Restock',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/inventory');
          },
        ),
      ),
    );
  }

  /// Check for low stock products and show notifications
  void checkAndNotifyLowStock(BuildContext context, List<Product> products) {
    for (final product in products) {
      if (product.isOutOfStock) {
        showOutOfStockNotification(context, product);
      } else if (product.isLowStock) {
        showLowStockNotification(context, product);
      }
    }
  }

  /// Get count of low stock products
  int getLowStockCount(List<Product> products) {
    return products.where((p) => p.isLowStock).length;
  }

  /// Get count of out of stock products
  int getOutOfStockCount(List<Product> products) {
    return products.where((p) => p.isOutOfStock).length;
  }

  /// Clear notification for a specific product
  void clearNotificationForProduct(String productId) {
    _activeNotifications.removeWhere((n) => n.productId == productId);
  }

  /// Clear all notifications
  void clearAllNotifications() {
    _activeNotifications.clear();
  }

  /// Get active notifications
  List<ProductLowStockNotification> getActiveNotifications() {
    return List.unmodifiable(_activeNotifications);
  }

  /// Show inventory summary notification
  void showInventorySummaryNotification(
      BuildContext context, List<Product> products) {
    final lowStockCount = getLowStockCount(products);
    final outOfStockCount = getOutOfStockCount(products);

    if (lowStockCount == 0 && outOfStockCount == 0) {
      return;
    }

    String message = '';
    Color backgroundColor = Colors.orange.shade700;

    if (outOfStockCount > 0 && lowStockCount > 0) {
      message = '$outOfStockCount out of stock, $lowStockCount low stock';
      backgroundColor = Colors.red.shade700;
    } else if (outOfStockCount > 0) {
      message = '$outOfStockCount products out of stock';
      backgroundColor = Colors.red.shade700;
    } else {
      message = '$lowStockCount products low in stock';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              outOfStockCount > 0 ? Icons.error_outline : Icons.warning_amber,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Inventory Alert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: 'Check Inventory',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/inventory');
          },
        ),
      ),
    );
  }
}

class ProductLowStockNotification {
  final String productId;
  final String productName;
  final int currentStock;
  final int minStockLevel;
  final DateTime timestamp;

  ProductLowStockNotification({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.minStockLevel,
    required this.timestamp,
  });
}
