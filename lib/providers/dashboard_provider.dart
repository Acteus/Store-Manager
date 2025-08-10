import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/product_repository.dart';
import '../repositories/sales_repository.dart';
import '../core/services/error_handler_service.dart';
import 'product_provider.dart'; // Import to get providers
import 'sales_provider.dart';

// Dashboard Analytics Provider
final dashboardAnalyticsProvider = StateNotifierProvider<DashboardAnalyticsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return DashboardAnalyticsNotifier(
    ref.watch(productRepositoryProvider),
    ref.watch(salesRepositoryProvider),
    ref.watch(errorHandlerProvider),
  );
});

// Quick Stats Provider
final quickStatsProvider = Provider<AsyncValue<Map<String, dynamic>>>((ref) {
  final analytics = ref.watch(dashboardAnalyticsProvider);
  
  return analytics.when(
    data: (data) {
      final quickStats = {
        'totalProducts': data['totalProducts'] ?? 0,
        'lowStockProducts': data['lowStockProducts'] ?? 0,
        'outOfStockProducts': data['outOfStockProducts'] ?? 0,
        'todaysSales': data['todaysSales'] ?? 0.0,
        'todaysTransactions': data['todaysTransactions'] ?? 0,
        'averageTransaction': data['averageTransaction'] ?? 0.0,
      };
      return AsyncValue.data(quickStats);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Recent Activity Provider
final recentActivityProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final analytics = ref.watch(dashboardAnalyticsProvider);
  
  return analytics.when(
    data: (data) {
      final activities = data['recentActivities'] as List<Map<String, dynamic>>? ?? [];
      return AsyncValue.data(activities);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Performance Metrics Provider
final performanceMetricsProvider = Provider<AsyncValue<Map<String, dynamic>>>((ref) {
  final analytics = ref.watch(dashboardAnalyticsProvider);
  
  return analytics.when(
    data: (data) {
      final metrics = {
        'salesGrowth': data['salesGrowth'] ?? 0.0,
        'inventoryTurnover': data['inventoryTurnover'] ?? 0.0,
        'topSellingCategory': data['topSellingCategory'] ?? 'N/A',
        'averageMargin': data['averageMargin'] ?? 0.0,
      };
      return AsyncValue.data(metrics);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Dashboard Analytics Notifier
class DashboardAnalyticsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final ProductRepository _productRepository;
  final SalesRepository _salesRepository;
  final ErrorHandlerService _errorHandler;

  DashboardAnalyticsNotifier(
    this._productRepository,
    this._salesRepository,
    this._errorHandler,
  ) : super(const AsyncValue.loading()) {
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    state = const AsyncValue.loading();
    
    try {
      // Load products data
      final productsResult = await _productRepository.getAllProducts();
      final products = productsResult.fold(
        (failure) => throw failure,
        (products) => products,
      );

      final lowStockResult = await _productRepository.getLowStockProducts();
      final lowStockProducts = lowStockResult.fold(
        (failure) => throw failure,
        (products) => products,
      );

      // Load sales data
      final salesResult = await _salesRepository.getAllSales();
      final sales = salesResult.fold(
        (failure) => throw failure,
        (sales) => sales,
      );

      final todaysSalesResult = await _salesRepository.getTodaysSales();
      final todaysSales = todaysSalesResult.fold(
        (failure) => throw failure,
        (sales) => sales,
      );

      final salesAnalyticsResult = await _salesRepository.getSalesAnalytics();
      final salesAnalytics = salesAnalyticsResult.fold(
        (failure) => throw failure,
        (analytics) => analytics,
      );

      // Calculate analytics
      final analytics = _calculateAnalytics(
        products,
        lowStockProducts,
        sales,
        todaysSales,
        salesAnalytics,
      );

      state = AsyncValue.data(analytics);
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Map<String, dynamic> _calculateAnalytics(
    List<dynamic> products,
    List<dynamic> lowStockProducts,
    List<dynamic> sales,
    List<dynamic> todaysSales,
    Map<String, dynamic> salesAnalytics,
  ) {
    final now = DateTime.now();
    
    // Product analytics
    final outOfStockProducts = products.where((p) => p.stockQuantity <= 0).length;
    final totalProducts = products.length;
    
    // Sales analytics
    final todaysSalesTotal = todaysSales.fold(0.0, (sum, sale) => sum + sale.total);
    final todaysTransactions = todaysSales.length;
    final averageTransaction = todaysTransactions > 0 ? todaysSalesTotal / todaysTransactions : 0.0;

    // Category analytics
    final categoryStats = <String, Map<String, dynamic>>{};
    for (final product in products) {
      final category = product.category;
      if (!categoryStats.containsKey(category)) {
        categoryStats[category] = {
          'count': 0,
          'totalValue': 0.0,
          'lowStock': 0,
        };
      }
      categoryStats[category]!['count'] = (categoryStats[category]!['count'] as int) + 1;
      categoryStats[category]!['totalValue'] = (categoryStats[category]!['totalValue'] as double) + (product.price * product.stockQuantity);
      if (product.isLowStock) {
        categoryStats[category]!['lowStock'] = (categoryStats[category]!['lowStock'] as int) + 1;
      }
    }

    // Find top selling category from sales data
    final categorySales = <String, double>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        // We'd need to match this with product categories in a real implementation
        categorySales['General'] = (categorySales['General'] ?? 0.0) + item.totalPrice;
      }
    }
    final topSellingCategory = categorySales.isNotEmpty 
        ? categorySales.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'N/A';

    // Sales growth (compare this week vs last week)
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart;

    final thisWeekSales = sales.where((sale) => sale.timestamp.isAfter(thisWeekStart)).toList();
    final lastWeekSales = sales.where((sale) => 
        sale.timestamp.isAfter(lastWeekStart) && sale.timestamp.isBefore(lastWeekEnd)).toList();

    final thisWeekTotal = thisWeekSales.fold(0.0, (sum, sale) => sum + sale.total);
    final lastWeekTotal = lastWeekSales.fold(0.0, (sum, sale) => sum + sale.total);
    
    final salesGrowth = lastWeekTotal > 0 ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal * 100) : 0.0;

    // Inventory turnover (simplified calculation)
    final totalInventoryValue = products.fold(0.0, (sum, product) => sum + (product.price * product.stockQuantity));
    final monthlySales = sales.where((sale) => 
        sale.timestamp.isAfter(DateTime(now.year, now.month, 1))).toList();
    final monthlySalesTotal = monthlySales.fold(0.0, (sum, sale) => sum + sale.total);
    final inventoryTurnover = totalInventoryValue > 0 ? (monthlySalesTotal / totalInventoryValue) : 0.0;

    // Recent activities
    final recentActivities = <Map<String, dynamic>>[];
    
    // Add recent sales
    for (final sale in sales.take(5)) {
      recentActivities.add({
        'type': 'sale',
        'title': 'Sale Completed',
        'description': 'Total: \$${sale.total.toStringAsFixed(2)} (${sale.items.length} items)',
        'timestamp': sale.timestamp,
        'icon': 'point_of_sale',
        'color': 'green',
      });
    }

    // Add low stock warnings
    for (final product in lowStockProducts.take(3)) {
      recentActivities.add({
        'type': 'warning',
        'title': 'Low Stock Alert',
        'description': '${product.name} - ${product.stockQuantity} remaining',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'icon': 'warning',
        'color': 'orange',
      });
    }

    // Sort by timestamp
    recentActivities.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return {
      // Basic stats
      'totalProducts': totalProducts,
      'lowStockProducts': lowStockProducts.length,
      'outOfStockProducts': outOfStockProducts,
      'todaysSales': todaysSalesTotal,
      'todaysTransactions': todaysTransactions,
      'averageTransaction': averageTransaction,
      
      // Performance metrics
      'salesGrowth': salesGrowth,
      'inventoryTurnover': inventoryTurnover,
      'topSellingCategory': topSellingCategory,
      'averageMargin': 25.0, // This would be calculated from cost vs selling price
      
      // Category analytics
      'categoryStats': categoryStats,
      
      // Recent activities
      'recentActivities': recentActivities,
      
      // Sales analytics from repository
      'salesAnalytics': salesAnalytics,
      
      // Timestamps
      'lastUpdated': now,
      'dataFreshness': 'Real-time',
    };
  }

  void refresh() {
    loadAnalytics();
  }

  void invalidateCache() {
    _productRepository.invalidateCache();
    _salesRepository.invalidateCache();
    loadAnalytics();
  }
}
