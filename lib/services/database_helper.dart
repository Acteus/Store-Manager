import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/sale_item.dart';
import '../models/inventory_count.dart';
import '../core/di/injection_container.dart' as di;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  late final Logger _logger = di.sl<Logger>();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the documents directory for better persistence
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'pos_inventory.db');

    if (kDebugMode) {
      _logger.i('Database path: $path');
      _logger.i('Database file exists: ${await File(path).exists()}');
    }

    try {
      final db = await openDatabase(
        path,
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (database) async {
          if (kDebugMode) {
            _logger.i('Database opened successfully');
            await _logDatabaseInfo(database);
          }
        },
      );

      if (kDebugMode) {
        _logger.i('Database initialized successfully');
      }

      return db;
    } catch (e) {
      _logger.e('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _logDatabaseInfo(Database db) async {
    try {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
      _logger.i('Available tables: ${tables.map((t) => t['name']).join(', ')}');

      final productCount =
          await db.rawQuery('SELECT COUNT(*) as count FROM products');
      _logger.i('Products in database: ${productCount.first['count']}');
    } catch (e) {
      _logger.w('Could not log database info: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        stockQuantity INTEGER NOT NULL DEFAULT 0,
        minStockLevel INTEGER NOT NULL DEFAULT 5,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        subtotal REAL NOT NULL,
        tax REAL NOT NULL,
        total REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        customerName TEXT,
        paymentMethod TEXT NOT NULL,
        isVoided INTEGER NOT NULL DEFAULT 0,
        voidedAt INTEGER,
        voidReason TEXT
      )
    ''');

    // Sale items table
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        productBarcode TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        quantity INTEGER NOT NULL,
        totalPrice REAL NOT NULL,
        FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    // Inventory counts table
    await db.execute('''
      CREATE TABLE inventory_counts (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        productBarcode TEXT NOT NULL,
        systemCount INTEGER NOT NULL,
        physicalCount INTEGER NOT NULL,
        variance INTEGER NOT NULL,
        countDate INTEGER NOT NULL,
        notes TEXT,
        countedBy TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    // Create indexes for better performance
    await _createIndexes(db);

    // Create FTS (Full Text Search) table for products
    await _createFtsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Clean up any existing triggers that might cause conflicts
      await _cleanupOldTriggers(db);

      // Add indexes and FTS table for existing databases
      await _createIndexes(db);
      await _createFtsTable(db);
    }

    if (oldVersion < 3) {
      // Add void-related columns to sales table
      try {
        await db.execute(
            'ALTER TABLE sales ADD COLUMN isVoided INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE sales ADD COLUMN voidedAt INTEGER');
        await db.execute('ALTER TABLE sales ADD COLUMN voidReason TEXT');
        _logger.i('Added void columns to sales table');
      } catch (e) {
        _logger.w('Error adding void columns (may already exist): $e');
      }
    }
  }

  Future<void> _cleanupOldTriggers(Database db) async {
    try {
      // Drop any existing FTS triggers
      await db.execute('DROP TRIGGER IF EXISTS products_fts_insert');
      await db.execute('DROP TRIGGER IF EXISTS products_fts_update');
      await db.execute('DROP TRIGGER IF EXISTS products_fts_delete');

      // Drop any existing search triggers
      await db.execute('DROP TRIGGER IF EXISTS products_search_insert');
      await db.execute('DROP TRIGGER IF EXISTS products_search_update');
      await db.execute('DROP TRIGGER IF EXISTS products_search_delete');

      _logger.i('Cleaned up old triggers');
    } catch (e) {
      _logger.w('Error cleaning up old triggers: $e');
    }
  }

  Future<void> _createIndexes(Database db) async {
    // Basic indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products (barcode)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category ON products (category)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_stock ON products (stockQuantity)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_low_stock ON products (stockQuantity, minStockLevel)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_created ON products (createdAt)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_updated ON products (updatedAt)');

    // Sales indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_timestamp ON sales (timestamp)');
    await db
        .execute('CREATE INDEX IF NOT EXISTS idx_sales_total ON sales (total)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_payment_method ON sales (paymentMethod)');

    // Sale items indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items (saleId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items (productId)');

    // Inventory counts indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_counts_product_id ON inventory_counts (productId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_counts_date ON inventory_counts (countDate)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_counts_variance ON inventory_counts (variance)');

    // Compound indexes for common queries
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category_stock ON products (category, stockQuantity)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_timestamp_total ON sales (timestamp, total)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_product_quantity ON sale_items (productId, quantity)');
  }

  Future<void> _createFtsTable(Database db) async {
    bool ftsEnabled = false;

    try {
      // Try to create FTS5 virtual table for full-text search
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS products_fts USING fts5(
          id UNINDEXED,
          name,
          barcode UNINDEXED,
          category,
          description,
          content='products',
          content_rowid='rowid'
        )
      ''');

      // Test if FTS5 table was created successfully
      await db.execute('SELECT name FROM products_fts LIMIT 1');
      ftsEnabled = true;
      _logger.i('FTS5 table created successfully');
    } catch (e) {
      _logger.w('FTS5 not supported, falling back to regular search: $e');
      ftsEnabled = false;

      // Clean up any partial FTS5 table
      try {
        await db.execute('DROP TABLE IF EXISTS products_fts');
      } catch (_) {}

      // FTS5 not available, create a regular table for search indexing
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products_search (
          id TEXT PRIMARY KEY,
          name TEXT,
          barcode TEXT,
          category TEXT,
          description TEXT,
          search_text TEXT
        )
      ''');

      // Create index for faster searching
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_products_search_text 
        ON products_search(search_text)
      ''');

      _logger.i('Fallback search table created successfully');
    }

    // Create triggers based on which table was created successfully
    if (ftsEnabled) {
      try {
        // Create FTS5 triggers
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS products_fts_insert AFTER INSERT ON products BEGIN
            INSERT INTO products_fts(id, name, barcode, category, description)
            VALUES (new.id, new.name, new.barcode, new.category, new.description);
          END
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS products_fts_update AFTER UPDATE ON products BEGIN
            UPDATE products_fts SET 
              name = new.name,
              barcode = new.barcode,
              category = new.category,
              description = new.description
            WHERE id = new.id;
          END
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS products_fts_delete AFTER DELETE ON products BEGIN
            DELETE FROM products_fts WHERE id = old.id;
          END
        ''');

        // Populate FTS table with existing data
        await db.execute('''
          INSERT OR IGNORE INTO products_fts(id, name, barcode, category, description)
          SELECT id, name, barcode, category, description FROM products
        ''');

        _logger.i('FTS5 triggers created successfully');
      } catch (e) {
        _logger.e('Failed to create FTS5 triggers: $e');
        // If triggers fail, disable FTS and fall back
        ftsEnabled = false;
        try {
          await db.execute('DROP TABLE IF EXISTS products_fts');
          await db.execute('DROP TRIGGER IF EXISTS products_fts_insert');
          await db.execute('DROP TRIGGER IF EXISTS products_fts_update');
          await db.execute('DROP TRIGGER IF EXISTS products_fts_delete');
        } catch (_) {}
      }
    }

    if (!ftsEnabled) {
      // Create fallback triggers for regular search table
      try {
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS products_search_insert AFTER INSERT ON products BEGIN
            INSERT OR REPLACE INTO products_search(id, name, barcode, category, description, search_text)
            VALUES (new.id, new.name, new.barcode, new.category, new.description, 
                    LOWER(new.name || ' ' || COALESCE(new.barcode, '') || ' ' || 
                          COALESCE(new.category, '') || ' ' || COALESCE(new.description, '')));
          END
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS products_search_update AFTER UPDATE ON products BEGIN
            UPDATE products_search SET 
              name = new.name,
              barcode = new.barcode,
              category = new.category,
              description = new.description,
              search_text = LOWER(new.name || ' ' || COALESCE(new.barcode, '') || ' ' || 
                                 COALESCE(new.category, '') || ' ' || COALESCE(new.description, ''))
            WHERE id = new.id;
          END
        ''');

        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS products_search_delete AFTER DELETE ON products BEGIN
            DELETE FROM products_search WHERE id = old.id;
          END
        ''');

        // Populate search table with existing data
        await db.execute('''
          INSERT OR REPLACE INTO products_search(id, name, barcode, category, description, search_text)
          SELECT id, name, barcode, category, description,
                 LOWER(name || ' ' || COALESCE(barcode, '') || ' ' || 
                       COALESCE(category, '') || ' ' || COALESCE(description, ''))
          FROM products
        ''');

        _logger.i('Fallback search triggers created successfully');
      } catch (e) {
        _logger.e('Failed to create fallback search triggers: $e');
      }
    }
  }

  // ==================== PRODUCT OPERATIONS ====================

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts({int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      orderBy: 'updatedAt DESC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> getProductsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return result.first['count'] as int;
  }

  Future<Product?> getProductById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Product>> getProductsByCategory(String category,
      {int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT * FROM products WHERE stockQuantity <= minStockLevel',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(String id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateProductStock(String productId, int newQuantity) async {
    final db = await database;
    return await db.update(
      'products',
      {
        'stockQuantity': newQuantity,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ==================== SALES OPERATIONS ====================

  Future<String> insertSaleWithItems(Sale sale) async {
    final db = await database;

    await db.transaction((txn) async {
      // Insert sale
      await txn.insert('sales', sale.toMap());

      // Insert sale items
      for (SaleItem item in sale.items) {
        await txn.insert('sale_items', {
          ...item.toMap(),
          'saleId': sale.id,
        });

        // Update product stock
        await txn.rawUpdate(
          'UPDATE products SET stockQuantity = stockQuantity - ?, updatedAt = ? WHERE id = ?',
          [
            item.quantity,
            DateTime.now().millisecondsSinceEpoch,
            item.productId
          ],
        );
      }
    });

    return sale.id;
  }

  Future<List<Sale>> getAllSales({int? limit, int? offset}) async {
    // By default, exclude voided sales
    return getNonVoidedSales(limit: limit, offset: offset);
  }

  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate,
      {int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> salesMaps = await db.query(
      'sales',
      where: 'timestamp BETWEEN ? AND ? AND isVoided = 0',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch
      ],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    List<Sale> sales = [];
    for (Map<String, dynamic> saleMap in salesMaps) {
      final List<Map<String, dynamic>> itemsMaps = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleMap['id']],
      );

      List<SaleItem> items =
          itemsMaps.map((map) => SaleItem.fromMap(map)).toList();
      sales.add(Sale.fromMap(saleMap, items));
    }

    return sales;
  }

  Future<int> getSalesCount() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT COUNT(*) as count FROM sales WHERE isVoided = 0');
    return result.first['count'] as int;
  }

  Future<Sale?> getSaleById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> salesMaps = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (salesMaps.isNotEmpty) {
      final List<Map<String, dynamic>> itemsMaps = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [id],
      );

      List<SaleItem> items =
          itemsMaps.map((map) => SaleItem.fromMap(map)).toList();
      return Sale.fromMap(salesMaps.first, items);
    }

    return null;
  }

  /// Void a sale - marks it as voided and restores inventory
  Future<void> voidSale(String saleId, String reason) async {
    final db = await database;

    await db.transaction((txn) async {
      // Get the sale first
      final saleData = await txn.query(
        'sales',
        where: 'id = ? AND isVoided = 0',
        whereArgs: [saleId],
      );

      if (saleData.isEmpty) {
        throw Exception('Sale not found or already voided');
      }

      // Get sale items to restore inventory
      final saleItems = await txn.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      // Restore inventory for each item
      for (final item in saleItems) {
        await txn.rawUpdate('''
          UPDATE products 
          SET stockQuantity = stockQuantity + ?, 
              updatedAt = ?
          WHERE id = ?
        ''', [
          item['quantity'],
          DateTime.now().millisecondsSinceEpoch,
          item['productId'],
        ]);
      }

      // Mark sale as voided
      await txn.update(
        'sales',
        {
          'isVoided': 1,
          'voidedAt': DateTime.now().millisecondsSinceEpoch,
          'voidReason': reason,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });

    _logger.i('Sale $saleId voided: $reason');
  }

  /// Permanently delete a voided sale from the database
  /// Note: This should only be used for voided sales to maintain data integrity
  Future<void> deleteVoidedSale(String saleId) async {
    final db = await database;

    await db.transaction((txn) async {
      // First verify the sale is voided
      final saleData = await txn.query(
        'sales',
        where: 'id = ? AND isVoided = 1',
        whereArgs: [saleId],
      );

      if (saleData.isEmpty) {
        throw Exception(
            'Sale not found or is not voided. Only voided sales can be deleted.');
      }

      // Delete sale items first (foreign key constraint)
      await txn.delete(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      // Delete the sale record
      await txn.delete(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });

    _logger.i('Voided sale $saleId permanently deleted from database');
  }

  /// Delete multiple voided sales at once
  Future<void> deleteMultipleVoidedSales(List<String> saleIds) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final saleId in saleIds) {
        // Verify each sale is voided
        final saleData = await txn.query(
          'sales',
          where: 'id = ? AND isVoided = 1',
          whereArgs: [saleId],
        );

        if (saleData.isEmpty) {
          _logger.w('Skipping sale $saleId - not found or not voided');
          continue;
        }

        // Delete sale items first
        await txn.delete(
          'sale_items',
          where: 'saleId = ?',
          whereArgs: [saleId],
        );

        // Delete the sale record
        await txn.delete(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }
    });

    _logger.i('Deleted ${saleIds.length} voided sales from database');
  }

  /// Clean up all voided sales older than specified days
  Future<int> cleanupOldVoidedSales({int olderThanDays = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));

    // Get voided sales older than cutoff date
    final oldVoidedSales = await db.query(
      'sales',
      columns: ['id'],
      where: 'isVoided = 1 AND voidedAt < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );

    if (oldVoidedSales.isEmpty) {
      return 0;
    }

    final saleIds = oldVoidedSales.map((sale) => sale['id'] as String).toList();
    await deleteMultipleVoidedSales(saleIds);

    _logger.i(
        'Cleaned up ${saleIds.length} voided sales older than $olderThanDays days');
    return saleIds.length;
  }

  /// Get all sales including voided ones with a flag
  Future<List<Sale>> getAllSalesIncludingVoided(
      {int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> salesMaps = await db.query(
      'sales',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    List<Sale> sales = [];
    for (Map<String, dynamic> saleMap in salesMaps) {
      final List<Map<String, dynamic>> itemsMaps = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleMap['id']],
      );

      List<SaleItem> items =
          itemsMaps.map((map) => SaleItem.fromMap(map)).toList();
      sales.add(Sale.fromMap(saleMap, items));
    }

    return sales;
  }

  /// Get only non-voided sales (default behavior)
  Future<List<Sale>> getNonVoidedSales({int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> salesMaps = await db.query(
      'sales',
      where: 'isVoided = 0',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    List<Sale> sales = [];
    for (Map<String, dynamic> saleMap in salesMaps) {
      final List<Map<String, dynamic>> itemsMaps = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleMap['id']],
      );

      List<SaleItem> items =
          itemsMaps.map((map) => SaleItem.fromMap(map)).toList();
      sales.add(Sale.fromMap(saleMap, items));
    }

    return sales;
  }

  /// Get sales totals for a specific date range (excluding voided sales)
  Future<double> getSalesTotalByDateRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(total) as totalSales 
      FROM sales 
      WHERE timestamp BETWEEN ? AND ? AND isVoided = 0
    ''', [startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch]);

    final totalSales = result.first['totalSales'];
    return totalSales != null ? (totalSales as num).toDouble() : 0.0;
  }

  /// Get today's sales total (excluding voided sales)
  Future<double> getTodaysSalesTotal() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getSalesTotalByDateRange(startOfDay, endOfDay);
  }

  /// Get count of voided sales
  Future<int> getVoidedSalesCount() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT COUNT(*) as count FROM sales WHERE isVoided = 1');
    return result.first['count'] as int;
  }

  /// Get total amount of voided sales
  Future<double> getVoidedSalesTotal() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(total) as totalVoided FROM sales WHERE isVoided = 1');

    final totalVoided = result.first['totalVoided'];
    return totalVoided != null ? (totalVoided as num).toDouble() : 0.0;
  }

  // ==================== INVENTORY COUNT OPERATIONS ====================

  Future<int> insertInventoryCount(InventoryCount count) async {
    final db = await database;
    return await db.insert('inventory_counts', count.toMap());
  }

  Future<List<InventoryCount>> getAllInventoryCounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory_counts',
      orderBy: 'countDate DESC',
    );
    return List.generate(maps.length, (i) => InventoryCount.fromMap(maps[i]));
  }

  Future<List<InventoryCount>> getInventoryCountsByProduct(
      String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory_counts',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'countDate DESC',
    );
    return List.generate(maps.length, (i) => InventoryCount.fromMap(maps[i]));
  }

  // ==================== SEARCH OPERATIONS ====================

  Future<List<Product>> searchProducts(String query,
      {int? limit, int? offset}) async {
    final db = await database;

    if (query.trim().isEmpty) {
      return getAllProducts(limit: limit, offset: offset);
    }

    // Check if FTS5 table exists and try FTS5 search first
    try {
      // Check if FTS5 table exists
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='products_fts'");

      if (tableCheck.isNotEmpty) {
        final List<Map<String, dynamic>> ftsResults = await db.rawQuery('''
          SELECT p.* FROM products p
          INNER JOIN products_fts fts ON p.id = fts.id
          WHERE products_fts MATCH ?
          ORDER BY rank
          LIMIT ? OFFSET ?
        ''', [query, limit ?? 100, offset ?? 0]);

        if (ftsResults.isNotEmpty) {
          _logger.d('Using FTS5 search');
          return List.generate(
              ftsResults.length, (i) => Product.fromMap(ftsResults[i]));
        }
      }
    } catch (e) {
      _logger.w('FTS5 search failed: $e');
    }

    // Try fallback search table
    try {
      // Check if fallback search table exists
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='products_search'");

      if (tableCheck.isNotEmpty) {
        final searchTerm = '%${query.toLowerCase()}%';
        final List<Map<String, dynamic>> searchResults = await db.rawQuery('''
          SELECT p.* FROM products p
          INNER JOIN products_search ps ON p.id = ps.id
          WHERE ps.search_text LIKE ?
          ORDER BY p.name ASC
          LIMIT ? OFFSET ?
        ''', [searchTerm, limit ?? 100, offset ?? 0]);

        if (searchResults.isNotEmpty) {
          _logger.d('Using fallback search table');
          return List.generate(
              searchResults.length, (i) => Product.fromMap(searchResults[i]));
        }
      }
    } catch (e) {
      _logger.w('Fallback search table failed: $e');
    }

    // Final fallback to basic LIKE queries
    _logger.d('Using basic LIKE search');
    final searchTerm = '%${query.toLowerCase()}%';
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: '''
        LOWER(name) LIKE ? OR 
        LOWER(barcode) LIKE ? OR 
        LOWER(category) LIKE ? OR 
        LOWER(description) LIKE ?
      ''',
      whereArgs: [searchTerm, searchTerm, searchTerm, searchTerm],
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Product>> getProductsWithFilters({
    String? category,
    double? minPrice,
    double? maxPrice,
    bool? lowStock,
    int? limit,
    int? offset,
  }) async {
    final db = await database;

    List<String> conditions = [];
    List<dynamic> args = [];

    if (category != null && category != 'All') {
      conditions.add('category = ?');
      args.add(category);
    }

    if (minPrice != null) {
      conditions.add('price >= ?');
      args.add(minPrice);
    }

    if (maxPrice != null) {
      conditions.add('price <= ?');
      args.add(maxPrice);
    }

    if (lowStock == true) {
      conditions.add('stockQuantity <= minStockLevel');
    }

    String whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : '';

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  // ==================== UTILITY OPERATIONS ====================

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'pos_inventory.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Forces database recreation by deleting and reinitializing
  /// Use this to fix database corruption or trigger issues
  Future<void> resetDatabase() async {
    try {
      await closeDatabase();
      await deleteDatabase();
      _logger.i('Database deleted successfully');

      // Reinitialize database
      await database;
      _logger.i('Database recreated successfully');
    } catch (e) {
      _logger.e('Error resetting database: $e');
      rethrow;
    }
  }

  // ==================== BACKUP AND RESTORE ====================

  /// Get the current database file path
  Future<String> getDatabasePath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, 'pos_inventory.db');
  }

  /// Check if database file exists
  Future<bool> databaseExists() async {
    final path = await getDatabasePath();
    return await File(path).exists();
  }

  /// Get database file size in bytes
  Future<int> getDatabaseSize() async {
    final path = await getDatabasePath();
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Export database to JSON for backup
  Future<Map<String, dynamic>> exportDatabaseToJson() async {
    try {
      final db = await database;

      _logger.i('Starting database export...');

      // Export all tables
      final products = await db.query('products');
      final sales = await db.query('sales');
      final saleItems = await db.query('sale_items');
      final inventoryCounts = await db.query('inventory_counts');

      final backup = {
        'version': 2,
        'exportDate': DateTime.now().toIso8601String(),
        'tables': {
          'products': products,
          'sales': sales,
          'sale_items': saleItems,
          'inventory_counts': inventoryCounts,
        }
      };

      _logger.i(
          'Database export completed. Products: ${products.length}, Sales: ${sales.length}');
      return backup;
    } catch (e) {
      _logger.e('Error exporting database: $e');
      rethrow;
    }
  }

  /// Save backup to external storage
  Future<String> createBackupFile() async {
    try {
      final backup = await exportDatabaseToJson();
      final jsonString = jsonEncode(backup);

      // Get external storage directory
      Directory? externalDir;
      if (Platform.isAndroid) {
        externalDir = await getExternalStorageDirectory();
      } else {
        externalDir = await getApplicationDocumentsDirectory();
      }

      if (externalDir == null) {
        throw Exception('Could not access storage directory');
      }

      final backupDir = Directory(join(externalDir.path, 'POS_Backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final fileName =
          'pos_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final backupFile = File(join(backupDir.path, fileName));

      await backupFile.writeAsString(jsonString);

      _logger.i('Backup created: ${backupFile.path}');
      return backupFile.path;
    } catch (e) {
      _logger.e('Error creating backup file: $e');
      rethrow;
    }
  }

  /// Restore database from JSON backup
  Future<void> restoreFromJson(Map<String, dynamic> backup) async {
    try {
      _logger.i('Starting database restore...');

      final db = await database;

      // Start transaction
      await db.transaction((txn) async {
        // Clear existing data
        await txn.delete('inventory_counts');
        await txn.delete('sale_items');
        await txn.delete('sales');
        await txn.delete('products');

        // Restore products
        final products = backup['tables']['products'] as List<dynamic>;
        for (final product in products) {
          await txn.insert('products', Map<String, dynamic>.from(product));
        }

        // Restore sales
        final sales = backup['tables']['sales'] as List<dynamic>;
        for (final sale in sales) {
          await txn.insert('sales', Map<String, dynamic>.from(sale));
        }

        // Restore sale items
        final saleItems = backup['tables']['sale_items'] as List<dynamic>;
        for (final item in saleItems) {
          await txn.insert('sale_items', Map<String, dynamic>.from(item));
        }

        // Restore inventory counts
        final inventoryCounts =
            backup['tables']['inventory_counts'] as List<dynamic>;
        for (final count in inventoryCounts) {
          await txn.insert(
              'inventory_counts', Map<String, dynamic>.from(count));
        }
      });

      _logger.i(
          'Database restore completed. Products: ${(backup['tables']['products'] as List).length}');
    } catch (e) {
      _logger.e('Error restoring database: $e');
      rethrow;
    }
  }

  /// Restore database from backup file
  Future<void> restoreFromBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      await restoreFromJson(backup);
      _logger.i('Database restored from: $filePath');
    } catch (e) {
      _logger.e('Error restoring from backup file: $e');
      rethrow;
    }
  }

  /// Verify database integrity
  Future<bool> verifyDatabaseIntegrity() async {
    try {
      final db = await database;
      final result = await db.rawQuery('PRAGMA integrity_check');
      final isOk = result.isNotEmpty && result.first.values.first == 'ok';

      if (kDebugMode) {
        _logger.i('Database integrity check: ${isOk ? 'PASSED' : 'FAILED'}');
      }

      return isOk;
    } catch (e) {
      _logger.e('Error checking database integrity: $e');
      return false;
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final db = await database;

      final productCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM products')) ??
          0;

      final salesCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM sales')) ??
          0;

      final saleItemsCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM sale_items')) ??
          0;

      final inventoryCountsCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM inventory_counts')) ??
          0;

      return {
        'products': productCount,
        'sales': salesCount,
        'sale_items': saleItemsCount,
        'inventory_counts': inventoryCountsCount,
      };
    } catch (e) {
      _logger.e('Error getting database stats: $e');
      return {};
    }
  }
}
