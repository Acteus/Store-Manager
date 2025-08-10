import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_count.dart';
import '../repositories/inventory_repository.dart';
import '../core/services/error_handler_service.dart';

import '../core/di/injection_container.dart' as di;
import 'product_provider.dart'; // Import to get errorHandlerProvider

// Inventory Repository Provider
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return di.sl<InventoryRepository>();
});

// Inventory Counts State
final inventoryCountsProvider = StateNotifierProvider<InventoryCountsNotifier,
    AsyncValue<List<InventoryCount>>>((ref) {
  return InventoryCountsNotifier(
    ref.watch(inventoryRepositoryProvider),
    ref.watch(errorHandlerProvider),
  );
});

// Inventory Analytics
final inventoryAnalyticsProvider = StateNotifierProvider<
    InventoryAnalyticsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return InventoryAnalyticsNotifier(
    ref.watch(inventoryRepositoryProvider),
    ref.watch(errorHandlerProvider),
  );
});

// Current Inventory Count Session
final inventoryCountSessionProvider =
    StateNotifierProvider<InventoryCountSessionNotifier, Map<String, dynamic>>(
        (ref) {
  return InventoryCountSessionNotifier();
});

// Inventory Count Filters
final inventoryCountFilterProvider =
    StateProvider<Map<String, dynamic>>((ref) => {
          'category': 'All',
          'hasVariance': false,
          'dateRange': null,
        });

// Inventory Counts Notifier
class InventoryCountsNotifier
    extends StateNotifier<AsyncValue<List<InventoryCount>>> {
  final InventoryRepository _repository;
  final ErrorHandlerService _errorHandler;

  InventoryCountsNotifier(this._repository, this._errorHandler)
      : super(const AsyncValue.loading()) {
    loadInventoryCounts();
  }

  Future<void> loadInventoryCounts() async {
    state = const AsyncValue.loading();

    final result = await _repository.getAllInventoryCounts();
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (counts) {
        state = AsyncValue.data(counts);
      },
    );
  }

  Future<void> createInventoryCount(InventoryCount count) async {
    final result = await _repository.createInventoryCount(count);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (_) {
        // Add the count to the beginning of the list
        state.whenData((counts) {
          state = AsyncValue.data([count, ...counts]);
        });
      },
    );
  }

  Future<void> loadInventoryCountsByProduct(String productId) async {
    state = const AsyncValue.loading();

    final result = await _repository.getInventoryCountsByProduct(productId);
    result.fold(
      (failure) {
        _errorHandler.logError(failure);
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (counts) {
        state = AsyncValue.data(counts);
      },
    );
  }

  void refresh() {
    loadInventoryCounts();
  }
}

// Inventory Analytics Notifier
class InventoryAnalyticsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final InventoryRepository _repository;
  final ErrorHandlerService _errorHandler;

  InventoryAnalyticsNotifier(this._repository, this._errorHandler)
      : super(const AsyncValue.loading()) {
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    state = const AsyncValue.loading();

    final result = await _repository.getInventoryAnalytics();
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

// Inventory Count Session Notifier
class InventoryCountSessionNotifier
    extends StateNotifier<Map<String, dynamic>> {
  InventoryCountSessionNotifier()
      : super({
          'isActive': false,
          'countedBy': 'Admin',
          'startTime': null,
          'physicalCounts': <String, int>{},
          'notes': <String, String>{},
          'scannedProducts': <String>[],
        });

  void startSession(String countedBy) {
    state = {
      ...state,
      'isActive': true,
      'countedBy': countedBy,
      'startTime': DateTime.now(),
      'physicalCounts': <String, int>{},
      'notes': <String, String>{},
      'scannedProducts': <String>[],
    };
  }

  void endSession() {
    state = {
      ...state,
      'isActive': false,
      'startTime': null,
      'physicalCounts': <String, int>{},
      'notes': <String, String>{},
      'scannedProducts': <String>[],
    };
  }

  void updatePhysicalCount(String productId, int count) {
    final physicalCounts = Map<String, int>.from(state['physicalCounts']);
    physicalCounts[productId] = count;

    state = {
      ...state,
      'physicalCounts': physicalCounts,
    };
  }

  void updateNotes(String productId, String notes) {
    final productNotes = Map<String, String>.from(state['notes']);
    if (notes.trim().isNotEmpty) {
      productNotes[productId] = notes;
    } else {
      productNotes.remove(productId);
    }

    state = {
      ...state,
      'notes': productNotes,
    };
  }

  void addScannedProduct(String productId) {
    final scannedProducts = List<String>.from(state['scannedProducts']);
    if (!scannedProducts.contains(productId)) {
      scannedProducts.add(productId);
      state = {
        ...state,
        'scannedProducts': scannedProducts,
      };
    }
  }

  void setCountedBy(String countedBy) {
    state = {
      ...state,
      'countedBy': countedBy,
    };
  }

  // Getters
  bool get isActive => state['isActive'] as bool;
  String get countedBy => state['countedBy'] as String;
  DateTime? get startTime => state['startTime'] as DateTime?;
  Map<String, int> get physicalCounts =>
      state['physicalCounts'] as Map<String, int>;
  Map<String, String> get notes => state['notes'] as Map<String, String>;
  List<String> get scannedProducts => state['scannedProducts'] as List<String>;

  int getTotalVariances(List<dynamic> products) {
    num totalVariances = 0;
    final counts = physicalCounts;

    for (final product in products) {
      final productId = product.id;
      final systemCount = product.stockQuantity;
      final physicalCount = counts[productId] ?? systemCount;
      final variance = (physicalCount - systemCount).abs();
      totalVariances += variance;
    }

    return totalVariances.toInt();
  }

  List<String> getProductsWithVariances(List<dynamic> products) {
    final productsWithVariances = <String>[];
    final counts = physicalCounts;

    for (final product in products) {
      final productId = product.id;
      final systemCount = product.stockQuantity;
      final physicalCount = counts[productId] ?? systemCount;

      if (physicalCount != systemCount) {
        productsWithVariances.add(productId);
      }
    }

    return productsWithVariances;
  }
}
