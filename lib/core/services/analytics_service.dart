import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';

class AnalyticsService {
  late final FirebaseAnalytics _analytics;
  late final Logger _logger;

  AnalyticsService() {
    _analytics = FirebaseAnalytics.instance;
    _logger = Logger();
  }

  // User Events
  Future<void> logUserAction(String action, {Map<String, dynamic>? parameters}) async {
    try {
      await _analytics.logEvent(
        name: 'user_action',
        parameters: {
          'action': action,
          ...?parameters,
        },
      );
    } catch (e) {
      _logger.w('Failed to log user action: $e');
    }
  }

  // Product Events
  Future<void> logProductAdded(String productId, String productName) async {
    try {
      await _analytics.logEvent(
        name: 'product_added',
        parameters: {
          'product_id': productId,
          'product_name': productName,
        },
      );
    } catch (e) {
      _logger.w('Failed to log product added: $e');
    }
  }

  Future<void> logProductViewed(String productId, String productName) async {
    try {
      await _analytics.logEvent(
        name: 'product_viewed',
        parameters: {
          'product_id': productId,
          'product_name': productName,
        },
      );
    } catch (e) {
      _logger.w('Failed to log product viewed: $e');
    }
  }

  Future<void> logProductUpdated(String productId) async {
    try {
      await _analytics.logEvent(
        name: 'product_updated',
        parameters: {
          'product_id': productId,
        },
      );
    } catch (e) {
      _logger.w('Failed to log product updated: $e');
    }
  }

  Future<void> logProductDeleted(String productId) async {
    try {
      await _analytics.logEvent(
        name: 'product_deleted',
        parameters: {
          'product_id': productId,
        },
      );
    } catch (e) {
      _logger.w('Failed to log product deleted: $e');
    }
  }

  // Sales Events
  Future<void> logSaleCompleted(String saleId, double total, int itemCount) async {
    try {
      await _analytics.logEvent(
        name: 'sale_completed',
        parameters: {
          'sale_id': saleId,
          'value': total,
          'item_count': itemCount,
        },
      );
    } catch (e) {
      _logger.w('Failed to log sale completed: $e');
    }
  }

  Future<void> logItemAddedToCart(String productId, int quantity) async {
    try {
      await _analytics.logEvent(
        name: 'add_to_cart',
        parameters: {
          'item_id': productId,
          'quantity': quantity,
        },
      );
    } catch (e) {
      _logger.w('Failed to log item added to cart: $e');
    }
  }

  Future<void> logItemRemovedFromCart(String productId) async {
    try {
      await _analytics.logEvent(
        name: 'remove_from_cart',
        parameters: {
          'item_id': productId,
        },
      );
    } catch (e) {
      _logger.w('Failed to log item removed from cart: $e');
    }
  }

  // Inventory Events
  Future<void> logInventoryCountStarted() async {
    try {
      await _analytics.logEvent(name: 'inventory_count_started');
    } catch (e) {
      _logger.w('Failed to log inventory count started: $e');
    }
  }

  Future<void> logInventoryCountCompleted(int variances) async {
    try {
      await _analytics.logEvent(
        name: 'inventory_count_completed',
        parameters: {
          'variances_found': variances,
        },
      );
    } catch (e) {
      _logger.w('Failed to log inventory count completed: $e');
    }
  }

  Future<void> logStockAdjustment(String productId, int adjustment) async {
    try {
      await _analytics.logEvent(
        name: 'stock_adjusted',
        parameters: {
          'product_id': productId,
          'adjustment': adjustment,
        },
      );
    } catch (e) {
      _logger.w('Failed to log stock adjustment: $e');
    }
  }

  // Barcode Events
  Future<void> logBarcodeScanned(String barcode, bool found) async {
    try {
      await _analytics.logEvent(
        name: 'barcode_scanned',
        parameters: {
          'barcode': barcode,
          'product_found': found,
        },
      );
    } catch (e) {
      _logger.w('Failed to log barcode scanned: $e');
    }
  }

  Future<void> logBarcodeGenerated(String productId) async {
    try {
      await _analytics.logEvent(
        name: 'barcode_generated',
        parameters: {
          'product_id': productId,
        },
      );
    } catch (e) {
      _logger.w('Failed to log barcode generated: $e');
    }
  }

  // Screen Events
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
      );
    } catch (e) {
      _logger.w('Failed to log screen view: $e');
    }
  }

  // Search Events
  Future<void> logSearchPerformed(String query, int resultCount) async {
    try {
      await _analytics.logEvent(
        name: 'search',
        parameters: {
          'search_term': query,
          'result_count': resultCount,
        },
      );
    } catch (e) {
      _logger.w('Failed to log search performed: $e');
    }
  }

  // Error Events
  Future<void> logError(String errorMessage, String? context) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_message': errorMessage,
          'context': context ?? 'unknown',
        },
      );
    } catch (e) {
      _logger.w('Failed to log error: $e');
    }
  }

  // Performance Events
  Future<void> logPerformanceEvent(String event, Duration duration) async {
    try {
      await _analytics.logEvent(
        name: 'performance_metric',
        parameters: {
          'event': event,
          'duration_ms': duration.inMilliseconds,
        },
      );
    } catch (e) {
      _logger.w('Failed to log performance event: $e');
    }
  }
}
