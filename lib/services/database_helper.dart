import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
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
    String path = join(await getDatabasesPath(), 'pos_inventory.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        paymentMethod TEXT NOT NULL
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
      // Add indexes and FTS table for existing databases
      await _createIndexes(db);
      await _createFtsTable(db);
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

      _logger.i('FTS5 table created successfully');
    } catch (e) {
      _logger.w('FTS5 not supported, falling back to regular search: $e');
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

    // Create triggers to keep search table in sync
    try {
      // Try FTS5 triggers first
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
      _logger.w('Creating fallback search triggers: $e');
      // Create fallback triggers for regular search table
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

  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate,
      {int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> salesMaps = await db.query(
      'sales',
      where: 'timestamp BETWEEN ? AND ?',
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
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sales');
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

    // First try FTS5 search
    try {
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
    } catch (e) {
      _logger.w('FTS5 search not available, trying fallback search: $e');
    }

    // Try fallback search table
    try {
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
    String path = join(await getDatabasesPath(), 'pos_inventory.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
