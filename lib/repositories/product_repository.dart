import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import '../models/product.dart';
import '../core/error/failures.dart';
import '../services/database_helper.dart';
import '../core/services/cache_service.dart';

abstract class ProductRepository {
  Future<Result<List<Product>>> getAllProducts();
  Future<Result<Product?>> getProductById(String id);
  Future<Result<Product?>> getProductByBarcode(String barcode);
  Future<Result<List<Product>>> getProductsByCategory(String category);
  Future<Result<List<Product>>> getLowStockProducts();
  Future<Result<List<Product>>> searchProducts(String query);
  Future<Result<Product>> addProduct(Product product);
  Future<Result<Product>> updateProduct(Product product);
  Future<Result<void>> deleteProduct(String id);
  Future<Result<void>> updateProductStock(String productId, int newQuantity);
  Future<Result<List<String>>> getCategories();
  Stream<List<Product>> watchProducts();
  void invalidateCache();
}

class ProductRepositoryImpl implements ProductRepository {
  final DatabaseHelper databaseHelper;
  final CacheService cacheService;
  final Logger logger;

  // In-memory cache for real-time updates
  List<Product>? _cachedProducts;
  List<String>? _cachedCategories;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Stream controller for reactive updates
  final _productsStreamController = StreamController<List<Product>>.broadcast();

  ProductRepositoryImpl({
    required this.databaseHelper,
    required this.cacheService,
    required this.logger,
  });

  @override
  Future<Result<List<Product>>> getAllProducts() async {
    try {
      // Check memory cache first
      if (_cachedProducts != null && _isCacheValid()) {
        logger.d('Returning products from memory cache');
        return Right(_cachedProducts!);
      }

      // Check persistent cache
      final cacheKey = cacheService.getProductsCacheKey();
      if (!cacheService.isCacheExpired(cacheKey)) {
        final cachedData = cacheService.getCacheItem<List<Product>>(cacheKey);
        if (cachedData != null) {
          logger.d('Returning products from persistent cache');
          _cachedProducts = cachedData;
          _lastCacheUpdate = DateTime.now();
          return Right(cachedData);
        }
      }

      // Fetch from database
      logger.d('Fetching products from database');
      final products = await databaseHelper.getAllProducts();
      
      // Update caches
      _cachedProducts = products;
      _lastCacheUpdate = DateTime.now();
      cacheService.setCacheItem(cacheKey, products);
      
      // Notify stream listeners
      _productsStreamController.add(products);
      
      return Right(products);
    } catch (e, stackTrace) {
      logger.e('Error fetching products', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load products: ${e.toString()}'));
    }
  }

  @override
  Future<Result<Product?>> getProductById(String id) async {
    try {
      // Check cache first
      if (_cachedProducts != null) {
        try {
          final product = _cachedProducts!.firstWhere((p) => p.id == id);
          return Right(product);
        } catch (e) {
          // Product not found in cache, continue to database
        }
      }

      // Fetch from database
      final product = await databaseHelper.getProductById(id);
      return Right(product);
    } catch (e, stackTrace) {
      logger.e('Error fetching product by ID', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load product: ${e.toString()}'));
    }
  }

  @override
  Future<Result<Product?>> getProductByBarcode(String barcode) async {
    try {
      // Check cache first
      if (_cachedProducts != null) {
        try {
          final product = _cachedProducts!.firstWhere(
            (p) => p.barcode == barcode,
          );
          return Right(product);
        } catch (_) {
          // Product not found in cache, continue to database
        }
      }

      // Fetch from database
      final product = await databaseHelper.getProductByBarcode(barcode);
      return Right(product);
    } catch (e, stackTrace) {
      logger.e('Error fetching product by barcode', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load product: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<Product>>> getProductsByCategory(String category) async {
    try {
      // Check cache first
      if (_cachedProducts != null && _isCacheValid()) {
        final filteredProducts = _cachedProducts!
            .where((p) => p.category == category)
            .toList();
        return Right(filteredProducts);
      }

      // Fetch from database
      final products = await databaseHelper.getProductsByCategory(category);
      return Right(products);
    } catch (e, stackTrace) {
      logger.e('Error fetching products by category', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load products: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<Product>>> getLowStockProducts() async {
    try {
      // Check cache first
      if (_cachedProducts != null && _isCacheValid()) {
        final lowStockProducts = _cachedProducts!
            .where((p) => p.isLowStock)
            .toList();
        return Right(lowStockProducts);
      }

      // Fetch from database
      final products = await databaseHelper.getLowStockProducts();
      return Right(products);
    } catch (e, stackTrace) {
      logger.e('Error fetching low stock products', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load low stock products: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<Product>>> searchProducts(String query) async {
    try {
      // For search, always check database for most current results
      // but also implement client-side search for cached data as fallback
      
      if (query.trim().isEmpty) {
        return await getAllProducts();
      }

      // Try database search first
      try {
        final products = await databaseHelper.searchProducts(query);
        return Right(products);
      } catch (e) {
        // Fallback to cached data search
        if (_cachedProducts != null) {
          final searchQuery = query.toLowerCase();
          final filteredProducts = _cachedProducts!.where((product) {
            return product.name.toLowerCase().contains(searchQuery) ||
                   product.barcode.contains(searchQuery) ||
                   product.category.toLowerCase().contains(searchQuery);
          }).toList();
          return Right(filteredProducts);
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      logger.e('Error searching products', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to search products: ${e.toString()}'));
    }
  }

  @override
  Future<Result<Product>> addProduct(Product product) async {
    try {
      await databaseHelper.insertProduct(product);
      
      // Update cache
      if (_cachedProducts != null) {
        _cachedProducts!.add(product);
        _productsStreamController.add(_cachedProducts!);
      }
      
      // Invalidate persistent cache to force refresh
      invalidateCache();
      
      logger.i('Product added: ${product.name}');
      return Right(product);
    } catch (e, stackTrace) {
      logger.e('Error adding product', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to add product: ${e.toString()}'));
    }
  }

  @override
  Future<Result<Product>> updateProduct(Product product) async {
    try {
      await databaseHelper.updateProduct(product);
      
      // Update cache
      if (_cachedProducts != null) {
        final index = _cachedProducts!.indexWhere((p) => p.id == product.id);
        if (index >= 0) {
          _cachedProducts![index] = product;
          _productsStreamController.add(_cachedProducts!);
        }
      }
      
      // Invalidate persistent cache
      invalidateCache();
      
      logger.i('Product updated: ${product.name}');
      return Right(product);
    } catch (e, stackTrace) {
      logger.e('Error updating product', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to update product: ${e.toString()}'));
    }
  }

  @override
  Future<Result<void>> deleteProduct(String id) async {
    try {
      await databaseHelper.deleteProduct(id);
      
      // Update cache
      if (_cachedProducts != null) {
        _cachedProducts!.removeWhere((p) => p.id == id);
        _productsStreamController.add(_cachedProducts!);
      }
      
      // Invalidate persistent cache
      invalidateCache();
      
      logger.i('Product deleted: $id');
      return const Right(null);
    } catch (e, stackTrace) {
      logger.e('Error deleting product', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to delete product: ${e.toString()}'));
    }
  }

  @override
  Future<Result<void>> updateProductStock(String productId, int newQuantity) async {
    try {
      await databaseHelper.updateProductStock(productId, newQuantity);
      
      // Update cache
      if (_cachedProducts != null) {
        final index = _cachedProducts!.indexWhere((p) => p.id == productId);
        if (index >= 0) {
          final updatedProduct = _cachedProducts![index].copyWith(
            stockQuantity: newQuantity,
            updatedAt: DateTime.now(),
          );
          _cachedProducts![index] = updatedProduct;
          _productsStreamController.add(_cachedProducts!);
        }
      }
      
      logger.i('Product stock updated: $productId -> $newQuantity');
      return const Right(null);
    } catch (e, stackTrace) {
      logger.e('Error updating product stock', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to update stock: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<String>>> getCategories() async {
    try {
      // Check cache first
      if (_cachedCategories != null) {
        return Right(_cachedCategories!);
      }

      // Get from products
      final productsResult = await getAllProducts();
      return productsResult.fold(
        (failure) => Left(failure),
        (products) {
          final categories = products.map((p) => p.category).toSet().toList();
          categories.sort();
          _cachedCategories = categories;
          return Right(categories);
        },
      );
    } catch (e, stackTrace) {
      logger.e('Error fetching categories', error: e, stackTrace: stackTrace);
      return Left(DatabaseFailure('Failed to load categories: ${e.toString()}'));
    }
  }

  @override
  Stream<List<Product>> watchProducts() {
    return _productsStreamController.stream;
  }

  @override
  void invalidateCache() {
    _cachedProducts = null;
    _cachedCategories = null;
    _lastCacheUpdate = null;
    cacheService.removeCacheItem(cacheService.getProductsCacheKey());
    cacheService.removeCacheItem(cacheService.getCategoriesCacheKey());
  }

  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;
  }

  void dispose() {
    _productsStreamController.close();
  }
}
