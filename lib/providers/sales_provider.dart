import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale_item.dart';
import '../models/product.dart';
import '../repositories/sales_repository.dart';
import '../core/services/error_handler_service.dart';
import '../core/services/analytics_service.dart';

import '../core/di/injection_container.dart' as di;
import 'product_provider.dart'; // Import to get errorHandlerProvider and analyticsProvider

// Sales Repository Provider
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return di.sl<SalesRepository>();
});

// Cart State
final cartProvider = StateNotifierProvider<CartNotifier, List<SaleItem>>((ref) {
  return CartNotifier(
    ref.watch(errorHandlerProvider),
    ref.watch(analyticsProvider),
  );
});

// Sales State
final salesProvider = StateNotifierProvider<SalesNotifier, AsyncValue<List<Sale>>>((ref) {
  return SalesNotifier(
    ref.watch(salesRepositoryProvider),
    ref.watch(errorHandlerProvider),
    ref.watch(analyticsProvider),
  );
});

// Sales Analytics
final salesAnalyticsProvider = StateNotifierProvider<SalesAnalyticsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return SalesAnalyticsNotifier(
    ref.watch(salesRepositoryProvider),
    ref.watch(errorHandlerProvider),
  );
});

// Current Sale State (for POS screen)
final currentSaleProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'paymentMethod': 'Cash',
  'customerName': '',
  'taxRate': 0.08,
});

// Cart Totals
final cartTotalsProvider = Provider<Map<String, double>>((ref) {
  final cartItems = ref.watch(cartProvider);
  final currentSale = ref.watch(currentSaleProvider);
  final taxRate = currentSale['taxRate'] as double;

  final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  final tax = subtotal * taxRate;
  final total = subtotal + tax;

  return {
    'subtotal': subtotal,
    'tax': tax,
    'total': total,
  };
});

// Today's Sales
final todaysSalesProvider = Provider<AsyncValue<List<Sale>>>((ref) {
  final sales = ref.watch(salesProvider);
  
  return sales.when(
    data: (salesList) {
      final today = DateTime.now();
      final todaysSales = salesList.where((sale) {
        return sale.timestamp.year == today.year &&
               sale.timestamp.month == today.month &&
               sale.timestamp.day == today.day;
      }).toList();
      return AsyncValue.data(todaysSales);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Cart State Notifier
class CartNotifier extends StateNotifier<List<SaleItem>> {
  final ErrorHandlerService _errorHandler;
  final AnalyticsService _analytics;

  CartNotifier(this._errorHandler, this._analytics) : super([]);

  void addToCart(Product product, {int quantity = 1}) {
    try {
      if (product.stockQuantity < quantity) {
        throw Exception('Insufficient stock for ${product.name}');
      }

      final existingIndex = state.indexWhere((item) => item.productId == product.id);
      
      if (existingIndex >= 0) {
        final existingItem = state[existingIndex];
        final newQuantity = existingItem.quantity + quantity;
        
        if (product.stockQuantity < newQuantity) {
          throw Exception('Insufficient stock for ${product.name}');
        }

        final updatedItem = existingItem.copyWith(
          quantity: newQuantity,
          totalPrice: product.price * newQuantity,
        );

        state = [
          ...state.sublist(0, existingIndex),
          updatedItem,
          ...state.sublist(existingIndex + 1),
        ];
      } else {
        final newItem = SaleItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          productId: product.id,
          productName: product.name,
          productBarcode: product.barcode,
          unitPrice: product.price,
          quantity: quantity,
          totalPrice: product.price * quantity,
        );

        state = [...state, newItem];
      }

      _analytics.logItemAddedToCart(product.id, quantity);
    } catch (e) {
      _errorHandler.logError(e);
      rethrow;
    }
  }

  void removeFromCart(String itemId) {
    try {
      final item = state.firstWhere((item) => item.id == itemId);
      state = state.where((item) => item.id != itemId).toList();
      
      _analytics.logItemRemovedFromCart(item.productId);
    } catch (e) {
      _errorHandler.logError(e);
      rethrow;
    }
  }

  void updateQuantity(String itemId, int newQuantity, Product product) {
    try {
      if (newQuantity <= 0) {
        removeFromCart(itemId);
        return;
      }

      if (product.stockQuantity < newQuantity) {
        throw Exception('Insufficient stock for ${product.name}');
      }

      final index = state.indexWhere((item) => item.id == itemId);
      if (index >= 0) {
        final updatedItem = state[index].copyWith(
          quantity: newQuantity,
          totalPrice: state[index].unitPrice * newQuantity,
        );

        state = [
          ...state.sublist(0, index),
          updatedItem,
          ...state.sublist(index + 1),
        ];
      }
    } catch (e) {
      _errorHandler.logError(e);
      rethrow;
    }
  }

  void clearCart() {
    state = [];
  }

  int get itemCount => state.length;
  
  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);
}

// Sales State Notifier
class SalesNotifier extends StateNotifier<AsyncValue<List<Sale>>> {
  final SalesRepository _repository;
  final ErrorHandlerService _errorHandler;
  final AnalyticsService _analytics;

  SalesNotifier(this._repository, this._errorHandler, this._analytics) 
      : super(const AsyncValue.loading()) {
    loadSales();
  }

  Future<void> loadSales() async {
    state = const AsyncValue.loading();
    
    final result = await _repository.getAllSales();
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (sales) {
        state = AsyncValue.data(sales);
      },
    );
  }

  Future<String?> createSale(Sale sale) async {
    final result = await _repository.createSale(sale);
    return result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
        return null;
      },
      (saleId) {
        _analytics.logSaleCompleted(saleId, sale.total, sale.items.length);
        // Add the sale to the beginning of the list
        state.whenData((sales) {
          state = AsyncValue.data([sale, ...sales]);
        });
        return saleId;
      },
    );
  }

  Future<void> loadSalesByDateRange(DateTime start, DateTime end) async {
    state = const AsyncValue.loading();
    
    final result = await _repository.getSalesByDateRange(start, end);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (sales) {
        state = AsyncValue.data(sales);
      },
    );
  }

  void invalidateCache() {
    _repository.invalidateCache();
    loadSales();
  }
}

// Sales Analytics Notifier
class SalesAnalyticsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final SalesRepository _repository;
  final ErrorHandlerService _errorHandler;

  SalesAnalyticsNotifier(this._repository, this._errorHandler) 
      : super(const AsyncValue.loading()) {
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    state = const AsyncValue.loading();
    
    final result = await _repository.getSalesAnalytics();
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (analytics) {
        state = AsyncValue.data(analytics);
      },
    );
  }

  void refresh() {
    loadAnalytics();
  }
}
