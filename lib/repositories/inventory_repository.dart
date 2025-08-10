import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import '../models/inventory_count.dart';
import '../core/error/failures.dart';
import '../services/database_helper.dart';

abstract class InventoryRepository {
  Future<Result<void>> createInventoryCount(InventoryCount count);
  Future<Result<List<InventoryCount>>> getAllInventoryCounts();
  Future<Result<List<InventoryCount>>> getInventoryCountsByProduct(String productId);
  Future<Result<Map<String, dynamic>>> getInventoryAnalytics();
  Stream<List<InventoryCount>> watchInventoryCounts();
}

class InventoryRepositoryImpl implements InventoryRepository {
  final DatabaseHelper databaseHelper;
  final Logger logger;

  // In-memory cache for recent inventory counts
  List<InventoryCount>? _cachedCounts;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  // Stream controller for reactive updates
  final _countsStreamController = StreamController<List<InventoryCount>>.broadcast();

  InventoryRepositoryImpl({
    required this.databaseHelper,
    required this.logger,
  });

  @override
  Future<Result<void>> createInventoryCount(InventoryCount count) async {
    try {
      await databaseHelper.insertInventoryCount(count);
      
      // Update cache
      if (_cachedCounts != null) {
        _cachedCounts!.insert(0, count); // Add to beginning for recent counts
        _countsStreamController.add(_cachedCounts!);
      }
      
      logger.i('Inventory count created for product: ${count.productName}');
      return const Right(null);
    } catch (e, stackTrace) {
      logger.e('Error creating inventory count', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to create inventory count: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<InventoryCount>>> getAllInventoryCounts() async {
    try {
      // Check memory cache first
      if (_cachedCounts != null && _isCacheValid()) {
        logger.d('Returning inventory counts from memory cache');
        return Right(_cachedCounts!);
      }

      // Fetch from database
      logger.d('Fetching inventory counts from database');
      final counts = await databaseHelper.getAllInventoryCounts();
      
      // Update cache
      _cachedCounts = counts;
      _lastCacheUpdate = DateTime.now();
      
      // Notify stream listeners
      _countsStreamController.add(counts);
      
      return Right(counts);
    } catch (e, stackTrace) {
      logger.e('Error fetching inventory counts', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load inventory counts: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<InventoryCount>>> getInventoryCountsByProduct(String productId) async {
    try {
      // Check cache first
      if (_cachedCounts != null && _isCacheValid()) {
        final productCounts = _cachedCounts!
            .where((count) => count.productId == productId)
            .toList();
        return Right(productCounts);
      }

      // Fetch from database
      final counts = await databaseHelper.getInventoryCountsByProduct(productId);
      return Right(counts);
    } catch (e, stackTrace) {
      logger.e('Error fetching inventory counts by product', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load inventory counts: ${e.toString()}'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getInventoryAnalytics() async {
    try {
      final countsResult = await getAllInventoryCounts();
      return countsResult.fold(
        (failure) => Left(failure),
        (counts) {
          final today = DateTime.now();
          final startOfMonth = DateTime(today.year, today.month, 1);
          
          // This month's counts
          final monthCounts = counts.where((count) => 
              count.countDate.isAfter(startOfMonth)).toList();
          
          // Variance analytics
          final totalVariances = counts.fold(0, (sum, count) => sum + count.variance.abs());
          final positiveVariances = counts.where((count) => count.variance > 0).length;
          final negativeVariances = counts.where((count) => count.variance < 0).length;
          
          // Most problematic products (highest variance)
          final productVariances = <String, int>{};
          for (final count in counts) {
            final productName = count.productName;
            productVariances[productName] = (productVariances[productName] ?? 0) + count.variance.abs();
          }
          
          final problematicProducts = productVariances.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          
          // Recent count frequency
          final lastWeek = today.subtract(const Duration(days: 7));
          final recentCounts = counts.where((count) => count.countDate.isAfter(lastWeek)).length;
          
          final analytics = {
            'total_counts': counts.length,
            'month_counts': monthCounts.length,
            'recent_counts': recentCounts,
            'total_variances': totalVariances,
            'positive_variances': positiveVariances,
            'negative_variances': negativeVariances,
            'accuracy_rate': counts.isNotEmpty 
                ? ((counts.length - counts.where((c) => c.hasVariance).length) / counts.length * 100)
                : 100.0,
            'problematic_products': problematicProducts.take(5).map((e) => {
              'product': e.key,
              'total_variance': e.value,
            }).toList(),
            'last_count_date': counts.isNotEmpty ? counts.first.countDate.toIso8601String() : null,
          };
          
          return Right(analytics);
        },
      );
    } catch (e, stackTrace) {
      logger.e('Error calculating inventory analytics', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to calculate analytics: ${e.toString()}'));
    }
  }

  @override
  Stream<List<InventoryCount>> watchInventoryCounts() {
    return _countsStreamController.stream;
  }

  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;
  }

  void dispose() {
    _countsStreamController.close();
  }
}
