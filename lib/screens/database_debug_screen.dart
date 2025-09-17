import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_helper.dart';
import '../models/product.dart';

class DatabaseDebugScreen extends StatefulWidget {
  const DatabaseDebugScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseDebugScreen> createState() => _DatabaseDebugScreenState();
}

class _DatabaseDebugScreenState extends State<DatabaseDebugScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Map<String, dynamic> _dbInfo = {};
  bool _isLoading = true;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbPath = await _databaseHelper.getDatabasePath();
      final dbExists = await _databaseHelper.databaseExists();
      final dbSize = await _databaseHelper.getDatabaseSize();
      final stats = await _databaseHelper.getDatabaseStats();
      final integrity = await _databaseHelper.verifyDatabaseIntegrity();
      final products = await _databaseHelper.getAllProducts();

      setState(() {
        _dbInfo = {
          'path': dbPath,
          'exists': dbExists,
          'size': dbSize,
          'stats': stats,
          'integrity': integrity,
        };
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _dbInfo = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    try {
      final backupPath = await _databaseHelper.createBackupFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created: $backupPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy Path',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: backupPath));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addTestProduct() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testProduct = Product(
        id: 'test-$timestamp',
        name: 'Test Product $timestamp',
        barcode: '$timestamp',
        price: 9.99,
        category: 'Test Category',
        description: 'Test product for debugging',
        stockQuantity: 10,
        minStockLevel: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Adding test product: ${testProduct.name}');
      await _databaseHelper.insertProduct(testProduct);
      print('Test product added successfully');

      // Verify the product was added
      final allProducts = await _databaseHelper.getAllProducts();
      print('Total products after insertion: ${allProducts.length}');

      await _loadDatabaseInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Test product added successfully. Total products: ${allProducts.length}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding test product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add test product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addSampleProducts() async {
    try {
      final sampleProducts = [
        Product(
          id: 'sample-1',
          name: 'Coca Cola 330ml',
          barcode: '1234567890123',
          price: 25.00,
          category: 'Beverages',
          description: 'Classic Coca Cola can',
          stockQuantity: 50,
          minStockLevel: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: 'sample-2',
          name: 'Lucky Me Beef',
          barcode: '2345678901234',
          price: 15.50,
          category: 'Instant Noodles',
          description: 'Lucky Me instant noodles beef flavor',
          stockQuantity: 30,
          minStockLevel: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: 'sample-3',
          name: 'Pancit Canton Sweet Style',
          barcode: '3456789012345',
          price: 18.00,
          category: 'Instant Noodles',
          description: 'Lucky Me Pancit Canton sweet style',
          stockQuantity: 25,
          minStockLevel: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: 'sample-4',
          name: 'Skyflakes Crackers',
          barcode: '4567890123456',
          price: 32.00,
          category: 'Snacks',
          description: 'Skyflakes original crackers',
          stockQuantity: 40,
          minStockLevel: 8,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: 'sample-5',
          name: 'Kopiko Black 3in1',
          barcode: '5678901234567',
          price: 8.50,
          category: 'Coffee',
          description: 'Kopiko Black 3in1 coffee',
          stockQuantity: 60,
          minStockLevel: 15,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (final product in sampleProducts) {
        try {
          await _databaseHelper.insertProduct(product);
          print('Added sample product: ${product.name}');
        } catch (e) {
          print('Failed to add ${product.name}: $e');
          // Continue with other products
        }
      }

      await _loadDatabaseInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${sampleProducts.length} sample products added!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding sample products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add sample products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Debug'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDatabaseInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Database Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Database Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (_dbInfo.containsKey('error'))
                            Text(
                              'Error: ${_dbInfo['error']}',
                              style: const TextStyle(color: Colors.red),
                            )
                          else ...[
                            _buildInfoRow('Path', _dbInfo['path'] ?? 'Unknown'),
                            _buildInfoRow(
                                'File Exists', '${_dbInfo['exists'] ?? false}'),
                            _buildInfoRow('File Size',
                                _formatFileSize(_dbInfo['size'] ?? 0)),
                            _buildInfoRow(
                                'Integrity Check',
                                _dbInfo['integrity'] == true
                                    ? '✅ PASSED'
                                    : '❌ FAILED'),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Statistics Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Database Statistics',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (_dbInfo['stats'] != null) ...[
                            _buildInfoRow('Products',
                                '${_dbInfo['stats']['products'] ?? 0}'),
                            _buildInfoRow(
                                'Sales', '${_dbInfo['stats']['sales'] ?? 0}'),
                            _buildInfoRow('Sale Items',
                                '${_dbInfo['stats']['sale_items'] ?? 0}'),
                            _buildInfoRow('Inventory Counts',
                                '${_dbInfo['stats']['inventory_counts'] ?? 0}'),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Products List Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Products in Database',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (_products.isEmpty)
                            const Text('No products found in database')
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return ListTile(
                                  title: Text(product.name),
                                  subtitle: Text('Barcode: ${product.barcode}'),
                                  trailing: Text(
                                      '₱${product.price.toStringAsFixed(2)}'),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _addTestProduct,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Test Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _createBackup,
                            icon: const Icon(Icons.backup),
                            label: const Text('Create Backup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addSampleProducts,
                          icon: const Icon(Icons.store),
                          label: const Text(
                              'Add Sample Store Products (Philippines)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Copy Path Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _dbInfo['path'] != null
                          ? () {
                              Clipboard.setData(
                                  ClipboardData(text: _dbInfo['path']));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Database path copied to clipboard')),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy DB Path'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
