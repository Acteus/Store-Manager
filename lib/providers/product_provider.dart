import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../core/services/error_handler_service.dart';
import '../core/services/analytics_service.dart';
import '../core/di/injection_container.dart' as di;

// Product Providers
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return di.sl<ProductRepository>();
});

final errorHandlerProvider = Provider<ErrorHandlerService>((ref) {
  return di.sl<ErrorHandlerService>();
});

final analyticsProvider = Provider<AnalyticsService>((ref) {
  return di.sl<AnalyticsService>();
});

// Products State
final productsProvider = StateNotifierProvider<ProductsNotifier, AsyncValue<List<Product>>>((ref) {
  return ProductsNotifier(
    ref.watch(productRepositoryProvider),
    ref.watch(errorHandlerProvider),
    ref.watch(analyticsProvider),
  );
});

// Search State
final productSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

// Filtered Products
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  final searchQuery = ref.watch(productSearchQueryProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return products.when(
    data: (productList) {
      var filtered = productList;

      // Apply category filter
      if (selectedCategory != 'All') {
        filtered = filtered.where((product) => product.category == selectedCategory).toList();
      }

      // Apply search filter
      if (searchQuery.isNotEmpty) {
        filtered = filtered.where((product) {
          return product.name.toLowerCase().contains(searchQuery) ||
                 product.barcode.contains(searchQuery) ||
                 product.category.toLowerCase().contains(searchQuery);
        }).toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Categories Provider
final categoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final products = ref.watch(productsProvider);
  
  return products.when(
    data: (productList) {
      final categories = productList.map((p) => p.category).toSet().toList();
      categories.sort();
      categories.insert(0, 'All');
      return AsyncValue.data(categories);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Low Stock Products
final lowStockProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  
  return products.when(
    data: (productList) {
      final lowStock = productList.where((p) => p.isLowStock).toList();
      return AsyncValue.data(lowStock);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Out of Stock Products
final outOfStockProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  
  return products.when(
    data: (productList) {
      final outOfStock = productList.where((p) => p.isOutOfStock).toList();
      return AsyncValue.data(outOfStock);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Product by ID
final productByIdProvider = Provider.family<AsyncValue<Product?>, String>((ref, id) {
  final products = ref.watch(productsProvider);
  
  return products.when(
    data: (productList) {
      try {
        final product = productList.firstWhere((p) => p.id == id);
        return AsyncValue.data(product);
      } catch (e) {
        return const AsyncValue.data(null);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Product by Barcode
final productByBarcodeProvider = Provider.family<AsyncValue<Product?>, String>((ref, barcode) {
  final products = ref.watch(productsProvider);
  
  return products.when(
    data: (productList) {
      try {
        final product = productList.firstWhere((p) => p.barcode == barcode);
        return AsyncValue.data(product);
      } catch (e) {
        return const AsyncValue.data(null);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Products State Notifier
class ProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductRepository _repository;
  final ErrorHandlerService _errorHandler;
  final AnalyticsService _analytics;

  ProductsNotifier(this._repository, this._errorHandler, this._analytics) 
      : super(const AsyncValue.loading()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = const AsyncValue.loading();
    
    final result = await _repository.getAllProducts();
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (products) {
        state = AsyncValue.data(products);
      },
    );
  }

  Future<void> addProduct(Product product) async {
    final result = await _repository.addProduct(product);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (addedProduct) {
        _analytics.logProductAdded(addedProduct.id, addedProduct.name);
        // Reload products to ensure consistency
        loadProducts();
      },
    );
  }

  Future<void> updateProduct(Product product) async {
    final result = await _repository.updateProduct(product);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (updatedProduct) {
        _analytics.logProductUpdated(updatedProduct.id);
        // Update the state with the new product
        state.whenData((products) {
          final index = products.indexWhere((p) => p.id == updatedProduct.id);
          if (index >= 0) {
            final updatedProducts = [...products];
            updatedProducts[index] = updatedProduct;
            state = AsyncValue.data(updatedProducts);
          }
        });
      },
    );
  }

  Future<void> deleteProduct(String productId) async {
    final result = await _repository.deleteProduct(productId);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        _analytics.logProductDeleted(productId);
        // Remove the product from state
        state.whenData((products) {
          final updatedProducts = products.where((p) => p.id != productId).toList();
          state = AsyncValue.data(updatedProducts);
        });
      },
    );
  }

  Future<void> updateProductStock(String productId, int newQuantity) async {
    final result = await _repository.updateProductStock(productId, newQuantity);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        _analytics.logStockAdjustment(productId, newQuantity);
        // Update the product stock in state
        state.whenData((products) {
          final index = products.indexWhere((p) => p.id == productId);
          if (index >= 0) {
            final updatedProducts = [...products];
            updatedProducts[index] = updatedProducts[index].copyWith(
              stockQuantity: newQuantity,
              updatedAt: DateTime.now(),
            );
            state = AsyncValue.data(updatedProducts);
          }
        });
      },
    );
  }

  Future<void> searchProducts(String query) async {
    if (query.isEmpty) {
      loadProducts();
      return;
    }

    state = const AsyncValue.loading();
    
    final result = await _repository.searchProducts(query);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (products) {
        _analytics.logSearchPerformed(query, products.length);
        state = AsyncValue.data(products);
      },
    );
  }

  void invalidateCache() {
    _repository.invalidateCache();
    loadProducts();
  }
}
