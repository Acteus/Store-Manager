import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../error/failures.dart';
import 'package:dartz/dartz.dart';

class CacheService {
  static const String _productCacheKey = 'cached_products';
  static const String _salesCacheKey = 'cached_sales';
  static const String _categoriesCacheKey = 'cached_categories';
  static const Duration _cacheExpiration = Duration(minutes: 30);

  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Memory Cache Operations
  void setCacheItem<T>(String key, T item, {Duration? expiration}) {
    _memoryCache[key] = item;
    _cacheTimestamps[key] = DateTime.now();
  }

  T? getCacheItem<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;

    final now = DateTime.now();
    if (now.difference(timestamp) > _cacheExpiration) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }

    return _memoryCache[key] as T?;
  }

  void removeCacheItem(String key) {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
  }

  void clearMemoryCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
  }

  // Persistent Cache Operations
  Future<Result<void>> cacheString(String key, String value) async {
    try {
      await init();
      final success = await _prefs!.setString(key, value);
      if (success) {
        return const Right(null);
      } else {
        return const Left(CacheFailure('Failed to cache string'));
      }
    } catch (e) {
      return Left(CacheFailure('Cache error: ${e.toString()}'));
    }
  }

  Future<Result<String?>> getCachedString(String key) async {
    try {
      await init();
      final value = _prefs!.getString(key);
      return Right(value);
    } catch (e) {
      return Left(CacheFailure('Cache retrieval error: ${e.toString()}'));
    }
  }

  Future<Result<void>> cacheJson(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      return await cacheString(key, jsonString);
    } catch (e) {
      return Left(CacheFailure('JSON encoding error: ${e.toString()}'));
    }
  }

  Future<Result<Map<String, dynamic>?>> getCachedJson(String key) async {
    try {
      final result = await getCachedString(key);
      return result.fold(
        (failure) => Left(failure),
        (jsonString) {
          if (jsonString == null) return const Right(null);
          try {
            final data = jsonDecode(jsonString) as Map<String, dynamic>;
            return Right(data);
          } catch (e) {
            return Left(CacheFailure('JSON decoding error: ${e.toString()}'));
          }
        },
      );
    } catch (e) {
      return Left(CacheFailure('Cache JSON retrieval error: ${e.toString()}'));
    }
  }

  Future<Result<void>> removeCachedItem(String key) async {
    try {
      await init();
      final success = await _prefs!.remove(key);
      if (success) {
        return const Right(null);
      } else {
        return const Left(CacheFailure('Failed to remove cached item'));
      }
    } catch (e) {
      return Left(CacheFailure('Cache removal error: ${e.toString()}'));
    }
  }

  Future<Result<void>> clearCache() async {
    try {
      await init();
      await _prefs!.clear();
      clearMemoryCache();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Cache clear error: ${e.toString()}'));
    }
  }

  // Specialized cache methods
  String getProductsCacheKey() => _productCacheKey;
  String getSalesCacheKey() => _salesCacheKey;
  String getCategoriesCacheKey() => _categoriesCacheKey;

  bool isCacheExpired(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _cacheExpiration;
  }
}
