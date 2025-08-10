import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../error/failures.dart';
import '../../services/database_helper.dart';
import '../../models/product.dart';
import '../../models/sale_item.dart';
import '../../models/inventory_count.dart';

class BackupService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  static const String backupVersion = '1.0';

  // Export all data to JSON
  Future<Result<File>> exportData({
    bool includeProducts = true,
    bool includeSales = true,
    bool includeInventoryCounts = true,
    String? customFileName,
  }) async {
    try {
      final backupData = <String, dynamic>{
        'version': backupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'exported_by': 'POS Inventory System',
      };

      // Export products
      if (includeProducts) {
        final products = await _databaseHelper.getAllProducts();
        backupData['products'] = products.map((p) => p.toMap()).toList();
      }

      // Export sales
      if (includeSales) {
        final sales = await _databaseHelper.getAllSales();
        backupData['sales'] = sales.map((s) => {
          ...s.toMap(),
          'items': s.items.map((item) => item.toMap()).toList(),
        }).toList();
      }

      // Export inventory counts
      if (includeInventoryCounts) {
        final counts = await _databaseHelper.getAllInventoryCounts();
        backupData['inventory_counts'] = counts.map((c) => c.toMap()).toList();
      }

      // Create backup file
      final fileName = customFileName ?? 
          'pos_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      
      final file = await _createBackupFile(fileName, backupData);
      
      return Right(file);
    } catch (e) {
      return Left(UnknownFailure('Failed to export data: ${e.toString()}'));
    }
  }

  // Import data from JSON file
  Future<Result<BackupImportResult>> importData(
    File backupFile, {
    bool replaceExisting = false,
    bool validateData = true,
  }) async {
    try {
      // Read and parse backup file
      final content = await backupFile.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      // Validate backup format
      if (validateData) {
        final validationResult = _validateBackupData(backupData);
        if (validationResult.isLeft()) {
          return validationResult.fold(
            (failure) => Left(failure),
            (_) => throw StateError('Unexpected success'),
          );
        }
      }

      final result = BackupImportResult();

      // Import products
      if (backupData.containsKey('products')) {
        final productsData = backupData['products'] as List;
        final importResult = await _importProducts(productsData, replaceExisting);
        result.productsImported = importResult;
      }

      // Import sales
      if (backupData.containsKey('sales')) {
        final salesData = backupData['sales'] as List;
        final importResult = await _importSales(salesData, replaceExisting);
        result.salesImported = importResult;
      }

      // Import inventory counts
      if (backupData.containsKey('inventory_counts')) {
        final countsData = backupData['inventory_counts'] as List;
        final importResult = await _importInventoryCounts(countsData, replaceExisting);
        result.inventoryCountsImported = importResult;
      }

      return Right(result);
    } catch (e) {
      return Left(UnknownFailure('Failed to import data: ${e.toString()}'));
    }
  }

  // Export products to CSV
  Future<Result<File>> exportProductsToCSV() async {
    try {
      final products = await _databaseHelper.getAllProducts();
      
      final csvLines = <String>[];
      
      // Header
      csvLines.add('ID,Name,Barcode,Price,Category,Description,Stock Quantity,Min Stock Level,Created At,Updated At');
      
      // Data rows
      for (final product in products) {
        final row = [
          product.id,
          _escapeCsvField(product.name),
          product.barcode,
          product.price.toString(),
          _escapeCsvField(product.category),
          _escapeCsvField(product.description ?? ''),
          product.stockQuantity.toString(),
          product.minStockLevel.toString(),
          product.createdAt.toIso8601String(),
          product.updatedAt.toIso8601String(),
        ].join(',');
        csvLines.add(row);
      }

      final fileName = 'products_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = await _createTextFile(fileName, csvLines.join('\n'));

      return Right(file);
    } catch (e) {
      return Left(UnknownFailure('Failed to export products to CSV: ${e.toString()}'));
    }
  }

  // Import products from CSV
  Future<Result<int>> importProductsFromCSV(File csvFile) async {
    try {
      final content = await csvFile.readAsString();
      final lines = content.split('\n');
      
      if (lines.isEmpty) {
        return const Left(ValidationFailure('CSV file is empty'));
      }

      // Skip header
      final dataLines = lines.skip(1).where((line) => line.trim().isNotEmpty);
      int importedCount = 0;

      for (final line in dataLines) {
        try {
          final fields = _parseCsvLine(line);
          if (fields.length < 8) continue; // Skip invalid rows

          final product = Product(
            id: fields[0].isNotEmpty ? fields[0] : _generateId(),
            name: fields[1],
            barcode: fields[2],
            price: double.parse(fields[3]),
            category: fields[4],
            description: fields[5].isNotEmpty ? fields[5] : null,
            stockQuantity: int.parse(fields[6]),
            minStockLevel: int.parse(fields[7]),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _databaseHelper.insertProduct(product);
          importedCount++;
        } catch (e) {
          // Skip invalid rows and continue
          continue;
        }
      }

      return Right(importedCount);
    } catch (e) {
      return Left(UnknownFailure('Failed to import products from CSV: ${e.toString()}'));
    }
  }

  // Share backup file
  Future<Result<void>> shareBackupFile(File backupFile) async {
    try {
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'POS System Backup - ${path.basename(backupFile.path)}',
      );
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to share backup file: ${e.toString()}'));
    }
  }

  // Pick backup file for import
  Future<Result<File?>> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return const Right(null); // User cancelled
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return const Left(ValidationFailure('Invalid file selected'));
      }

      return Right(File(filePath));
    } catch (e) {
      return Left(UnknownFailure('Failed to pick backup file: ${e.toString()}'));
    }
  }

  // Get backup info
  Future<Result<BackupInfo>> getBackupInfo(File backupFile) async {
    try {
      final content = await backupFile.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      final info = BackupInfo(
        fileName: path.basename(backupFile.path),
        version: backupData['version'] as String? ?? 'Unknown',
        timestamp: backupData['timestamp'] != null 
            ? DateTime.parse(backupData['timestamp'] as String)
            : null,
        productsCount: backupData['products'] != null 
            ? (backupData['products'] as List).length 
            : 0,
        salesCount: backupData['sales'] != null 
            ? (backupData['sales'] as List).length 
            : 0,
        inventoryCountsCount: backupData['inventory_counts'] != null 
            ? (backupData['inventory_counts'] as List).length 
            : 0,
        fileSizeBytes: await backupFile.length(),
      );

      return Right(info);
    } catch (e) {
      return Left(UnknownFailure('Failed to read backup info: ${e.toString()}'));
    }
  }

  // Clear all data (for testing or reset)
  Future<Result<void>> clearAllData() async {
    try {
      await _databaseHelper.deleteDatabase();
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to clear data: ${e.toString()}'));
    }
  }

  // Private helper methods

  Future<File> _createBackupFile(String fileName, Map<String, dynamic> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(path.join(directory.path, 'backups'));
    
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final file = File(path.join(backupsDir.path, fileName));
    await file.writeAsString(jsonEncode(data));
    
    return file;
  }

  Future<File> _createTextFile(String fileName, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(path.join(directory.path, 'exports'));
    
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final file = File(path.join(exportsDir.path, fileName));
    await file.writeAsString(content);
    
    return file;
  }

  Result<void> _validateBackupData(Map<String, dynamic> backupData) {
    // Check version compatibility
    final version = backupData['version'] as String?;
    if (version == null) {
      return const Left(ValidationFailure('Backup file missing version information'));
    }

    // For now, accept all versions (in future, check compatibility)
    
    // Validate data structure
    if (backupData.containsKey('products')) {
      final products = backupData['products'];
      if (products is! List) {
        return const Left(ValidationFailure('Invalid products data format'));
      }
    }

    if (backupData.containsKey('sales')) {
      final sales = backupData['sales'];
      if (sales is! List) {
        return const Left(ValidationFailure('Invalid sales data format'));
      }
    }

    return const Right(null);
  }

  Future<int> _importProducts(List productsData, bool replaceExisting) async {
    int importedCount = 0;

    for (final productData in productsData) {
      try {
        final product = Product.fromMap(productData as Map<String, dynamic>);
        
        if (replaceExisting) {
          await _databaseHelper.insertProduct(product);
        } else {
          // Check if product already exists
          final existing = await _databaseHelper.getProductById(product.id);
          if (existing == null) {
            await _databaseHelper.insertProduct(product);
          }
        }
        
        importedCount++;
      } catch (e) {
        // Skip invalid products
        continue;
      }
    }

    return importedCount;
  }

  Future<int> _importSales(List salesData, bool replaceExisting) async {
    int importedCount = 0;

    for (final saleData in salesData) {
      try {
        final saleMap = saleData as Map<String, dynamic>;
        final itemsData = saleMap['items'] as List;
        final items = itemsData
            .map((itemData) => SaleItem.fromMap(itemData as Map<String, dynamic>))
            .toList();
        
        final sale = Sale.fromMap(saleMap, items);
        
        if (replaceExisting) {
          await _databaseHelper.insertSaleWithItems(sale);
        } else {
          // Check if sale already exists
          final existing = await _databaseHelper.getSaleById(sale.id);
          if (existing == null) {
            await _databaseHelper.insertSaleWithItems(sale);
          }
        }
        
        importedCount++;
      } catch (e) {
        // Skip invalid sales
        continue;
      }
    }

    return importedCount;
  }

  Future<int> _importInventoryCounts(List countsData, bool replaceExisting) async {
    int importedCount = 0;

    for (final countData in countsData) {
      try {
        final count = InventoryCount.fromMap(countData as Map<String, dynamic>);
        await _databaseHelper.insertInventoryCount(count);
        importedCount++;
      } catch (e) {
        // Skip invalid counts
        continue;
      }
    }

    return importedCount;
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    fields.add(buffer.toString());
    return fields;
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

class BackupImportResult {
  int productsImported = 0;
  int salesImported = 0;
  int inventoryCountsImported = 0;

  int get totalImported => productsImported + salesImported + inventoryCountsImported;
}

class BackupInfo {
  final String fileName;
  final String version;
  final DateTime? timestamp;
  final int productsCount;
  final int salesCount;
  final int inventoryCountsCount;
  final int fileSizeBytes;

  BackupInfo({
    required this.fileName,
    required this.version,
    this.timestamp,
    required this.productsCount,
    required this.salesCount,
    required this.inventoryCountsCount,
    required this.fileSizeBytes,
  });

  double get fileSizeMB => fileSizeBytes / (1024 * 1024);
  
  int get totalRecords => productsCount + salesCount + inventoryCountsCount;
}
