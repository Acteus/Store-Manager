import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import '../models/sale_item.dart';
import '../core/error/failures.dart';
import '../services/database_helper.dart';
import '../core/services/cache_service.dart';

abstract class SalesRepository {
  Future<Result<String>> createSale(Sale sale);
  Future<Result<List<Sale>>> getAllSales({int? limit, int? offset});
  Future<Result<Sale?>> getSaleById(String id);
  Future<Result<List<Sale>>> getSalesByDateRange(DateTime start, DateTime end);
  Future<Result<List<Sale>>> getTodaysSales();
  Future<Result<Map<String, dynamic>>> getSalesAnalytics();
  Stream<List<Sale>> watchRecentSales();
  void invalidateCache();
}

class SalesRepositoryImpl implements SalesRepository {
  final DatabaseHelper databaseHelper;
  final CacheService cacheService;
  final Logger logger;

  // In-memory cache for recent sales
  List<Sale>? _cachedSales;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 2);

  // Stream controller for reactive updates
  final _salesStreamController = StreamController<List<Sale>>.broadcast();

  SalesRepositoryImpl({
    required this.databaseHelper,
    required this.cacheService,
    required this.logger,
  });

  @override
  Future<Result<String>> createSale(Sale sale) async {
    try {
      final saleId = await databaseHelper.insertSaleWithItems(sale);
      
      // Update cache
      if (_cachedSales != null) {
        _cachedSales!.insert(0, sale); // Add to beginning for recent sales
        // Keep only last 50 sales in memory cache
        if (_cachedSales!.length > 50) {
          _cachedSales = _cachedSales!.take(50).toList();
        }
        _salesStreamController.add(_cachedSales!);
      }
      
      // Invalidate persistent cache
      invalidateCache();
      
      logger.i('Sale created: $saleId, Total: ${sale.total}');
      return Right(saleId);
    } catch (e, stackTrace) {
      logger.e('Error creating sale', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to create sale: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<Sale>>> getAllSales({int? limit, int? offset}) async {
    try {
      // For paginated requests, always go to database
      if (limit != null || offset != null) {
        final sales = await _getPaginatedSales(limit: limit, offset: offset);
        return Right(sales);
      }

      // Check memory cache for full list
      if (_cachedSales != null && _isCacheValid()) {
        logger.d('Returning sales from memory cache');
        return Right(_cachedSales!);
      }

      // Check persistent cache
      final cacheKey = cacheService.getSalesCacheKey();
      if (!cacheService.isCacheExpired(cacheKey)) {
        final cachedData = cacheService.getCacheItem<List<Sale>>(cacheKey);
        if (cachedData != null) {
          logger.d('Returning sales from persistent cache');
          _cachedSales = cachedData;
          _lastCacheUpdate = DateTime.now();
          return Right(cachedData);
        }
      }

      // Fetch from database
      logger.d('Fetching sales from database');
      final sales = await databaseHelper.getAllSales();
      
      // Update caches
      _cachedSales = sales;
      _lastCacheUpdate = DateTime.now();
      cacheService.setCacheItem(cacheKey, sales);
      
      // Notify stream listeners
      _salesStreamController.add(sales);
      
      return Right(sales);
    } catch (e, stackTrace) {
      logger.e('Error fetching sales', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load sales: ${e.toString()}'));
    }
  }

  Future<List<Sale>> _getPaginatedSales({int? limit, int? offset}) async {
    // This would be implemented with proper SQL LIMIT and OFFSET
    // For now, we'll simulate with the existing method
    final allSales = await databaseHelper.getAllSales();
    
    final startIndex = offset ?? 0;
    final endIndex = limit != null ? startIndex + limit : allSales.length;
    
    if (startIndex >= allSales.length) return [];
    
    return allSales.sublist(
      startIndex, 
      endIndex > allSales.length ? allSales.length : endIndex
    );
  }

  @override
  Future<Result<Sale?>> getSaleById(String id) async {
    try {
      // Check cache first
      if (_cachedSales != null) {
        try {
          final sale = _cachedSales!.firstWhere((s) => s.id == id);
          return Right(sale);
        } catch (_) {
          // Sale not found in cache, continue to database
        }
      }

      // Fetch from database
      final sale = await databaseHelper.getSaleById(id);
      return Right(sale);
    } catch (e, stackTrace) {
      logger.e('Error fetching sale by ID', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load sale: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<Sale>>> getSalesByDateRange(DateTime start, DateTime end) async {
    try {
      // Check cache first if it's a today's request
      final today = DateTime.now();
      final isToday = start.year == today.year && 
                     start.month == today.month && 
                     start.day == today.day;

      if (isToday && _cachedSales != null && _isCacheValid()) {
        final todaysSales = _cachedSales!.where((sale) {
          return sale.timestamp.isAfter(start) && sale.timestamp.isBefore(end);
        }).toList();
        return Right(todaysSales);
      }

      // Fetch all sales and filter (in a real app, this would be a database query)
      final allSalesResult = await getAllSales();
      return allSalesResult.fold(
        (failure) => Left(failure),
        (sales) {
          final filteredSales = sales.where((sale) {
            return sale.timestamp.isAfter(start) && sale.timestamp.isBefore(end);
          }).toList();
          return Right(filteredSales);
        },
      );
    } catch (e, stackTrace) {
      logger.e('Error fetching sales by date range', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load sales: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<Sale>>> getTodaysSales() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      return await getSalesByDateRange(startOfDay, endOfDay);
    } catch (e, stackTrace) {
      logger.e('Error fetching today\'s sales', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load today\'s sales: ${e.toString()}'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getSalesAnalytics() async {
    try {
      final salesResult = await getAllSales();
      return salesResult.fold(
        (failure) => Left(failure),
        (sales) {
          final today = DateTime.now();
          final startOfDay = DateTime(today.year, today.month, today.day);
          
          // Today's analytics
          final todaysSales = sales.where((sale) => sale.timestamp.isAfter(startOfDay)).toList();
          final todaysTotal = todaysSales.fold(0.0, (sum, sale) => sum + sale.total);
          
          // This week's analytics
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
          final weekSales = sales.where((sale) => sale.timestamp.isAfter(startOfWeek)).toList();
          final weekTotal = weekSales.fold(0.0, (sum, sale) => sum + sale.total);
          
          // This month's analytics
          final startOfMonth = DateTime(today.year, today.month, 1);
          final monthSales = sales.where((sale) => sale.timestamp.isAfter(startOfMonth)).toList();
          final monthTotal = monthSales.fold(0.0, (sum, sale) => sum + sale.total);
          
          // Best-selling items
          final itemSales = <String, int>{};
          for (final sale in sales) {
            for (final item in sale.items) {
              itemSales[item.productName] = (itemSales[item.productName] ?? 0) + item.quantity;
            }
          }
          
          final bestSelling = itemSales.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          
          final analytics = {
            'today': {
              'sales_count': todaysSales.length,
              'total_amount': todaysTotal,
              'average_sale': todaysSales.isNotEmpty ? todaysTotal / todaysSales.length : 0.0,
            },
            'week': {
              'sales_count': weekSales.length,
              'total_amount': weekTotal,
              'average_sale': weekSales.isNotEmpty ? weekTotal / weekSales.length : 0.0,
            },
            'month': {
              'sales_count': monthSales.length,
              'total_amount': monthTotal,
              'average_sale': monthSales.isNotEmpty ? monthTotal / monthSales.length : 0.0,
            },
            'best_selling': bestSelling.take(5).map((e) => {
              'product': e.key,
              'quantity': e.value,
            }).toList(),
          };
          
          return Right(analytics);
        },
      );
    } catch (e, stackTrace) {
      logger.e('Error calculating sales analytics', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to calculate analytics: ${e.toString()}'));
    }
  }

  @override
  Stream<List<Sale>> watchRecentSales() {
    return _salesStreamController.stream;
  }

  @override
  void invalidateCache() {
    _cachedSales = null;
    _lastCacheUpdate = null;
    cacheService.removeCacheItem(cacheService.getSalesCacheKey());
  }

  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;
  }

  void dispose() {
    _salesStreamController.close();
  }
}
