import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/inventory_count.dart';
import '../services/database_helper.dart';
import '../services/barcode_service.dart';

class InventoryCountScreen extends StatefulWidget {
  const InventoryCountScreen({Key? key}) : super(key: key);

  @override
  State<InventoryCountScreen> createState() => _InventoryCountScreenState();
}

class _InventoryCountScreenState extends State<InventoryCountScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final BarcodeService _barcodeService = BarcodeService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _countedByController =
      TextEditingController(text: 'Admin');

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  Map<String, int> _physicalCounts = {};
  Map<String, String> _notes = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _selectedCategory = 'All';
  Set<String> _categories = {'All'};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _databaseHelper.getAllProducts();
      final categories = products.map((p) => p.category).toSet();

      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = {'All', ...categories};
        _isLoading = false;

        // Initialize physical counts with system counts
        for (var product in products) {
          _physicalCounts[product.id] = product.stockQuantity;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredProducts = _products.where((product) {
        final matchesSearch = query.isEmpty ||
            product.name.toLowerCase().contains(query) ||
            product.barcode.contains(query) ||
            product.category.toLowerCase().contains(query);

        final matchesCategory =
            _selectedCategory == 'All' || product.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _scanProductForCount() async {
    final barcode = await Navigator.pushNamed(
      context,
      '/barcode_scanner',
      arguments: {'returnResult': true},
    ) as String?;

    if (barcode != null) {
      final product = _filteredProducts.firstWhere(
        (p) => p.barcode == barcode,
        orElse: () => _products.firstWhere(
          (p) => p.barcode == barcode,
          orElse: () => throw Exception('Product not found'),
        ),
      );

      _showCountDialog(product);
    }
  }

  void _showCountDialog(Product product) {
    final currentCount = _physicalCounts[product.id] ?? product.stockQuantity;
    final controller = TextEditingController(text: currentCount.toString());
    final notesController =
        TextEditingController(text: _notes[product.id] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Count: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('System Count: ${product.stockQuantity}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Physical Count',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              if (count != null && count >= 0) {
                setState(() {
                  _physicalCounts[product.id] = count;
                  if (notesController.text.trim().isNotEmpty) {
                    _notes[product.id] = notesController.text.trim();
                  } else {
                    _notes.remove(product.id);
                  }
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInventoryCounts() async {
    if (_countedByController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter who performed the count')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final countDate = DateTime.now();

      for (var product in _products) {
        final physicalCount =
            _physicalCounts[product.id] ?? product.stockQuantity;
        final variance = physicalCount - product.stockQuantity;

        // Only save counts that have been changed or have notes
        if (physicalCount != product.stockQuantity ||
            _notes.containsKey(product.id)) {
          final inventoryCount = InventoryCount(
            id: const Uuid().v4(),
            productId: product.id,
            productName: product.name,
            productBarcode: product.barcode,
            systemCount: product.stockQuantity,
            physicalCount: physicalCount,
            variance: variance,
            countDate: countDate,
            notes: _notes[product.id],
            countedBy: _countedByController.text.trim(),
          );

          await _databaseHelper.insertInventoryCount(inventoryCount);

          // Update product stock to match physical count
          if (variance != 0) {
            await _databaseHelper.updateProductStock(product.id, physicalCount);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory count saved successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving inventory count: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  int get _totalVariances {
    return _products.fold(0, (sum, product) {
      final physicalCount =
          _physicalCounts[product.id] ?? product.stockQuantity;
      final variance = physicalCount - product.stockQuantity;
      return sum + variance.abs();
    });
  }

  List<Product> get _productsWithVariances {
    return _products.where((product) {
      final physicalCount =
          _physicalCounts[product.id] ?? product.stockQuantity;
      return physicalCount != product.stockQuantity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Count'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanProductForCount,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveInventoryCounts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Count Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryCard(
                      title: 'Total Products',
                      value: _products.length.toString(),
                      icon: Icons.inventory_2,
                      color: Colors.blue,
                    ),
                    _SummaryCard(
                      title: 'With Variances',
                      value: _productsWithVariances.length.toString(),
                      icon: Icons.warning,
                      color: Colors.orange,
                    ),
                    _SummaryCard(
                      title: 'Total Variances',
                      value: _totalVariances.toString(),
                      icon: Icons.difference,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _countedByController,
                  decoration: const InputDecoration(
                    labelText: 'Counted By',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ],
            ),
          ),

          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanProductForCount,
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterProducts();
                            },
                          ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => _filterProducts(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Category: '),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                          _filterProducts();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final physicalCount = _physicalCounts[product.id] ??
                              product.stockQuantity;
                          final variance =
                              physicalCount - product.stockQuantity;

                          return _CountListItem(
                            product: product,
                            physicalCount: physicalCount,
                            variance: variance,
                            notes: _notes[product.id],
                            barcodeService: _barcodeService,
                            onTap: () => _showCountDialog(product),
                          );
                        },
                      ),
          ),

          // Save Button
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveInventoryCounts,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Inventory Count'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _countedByController.dispose();
    super.dispose();
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CountListItem extends StatelessWidget {
  final Product product;
  final int physicalCount;
  final int variance;
  final String? notes;
  final BarcodeService barcodeService;
  final VoidCallback onTap;

  const _CountListItem({
    required this.product,
    required this.physicalCount,
    required this.variance,
    this.notes,
    required this.barcodeService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: variance == 0
              ? Colors.green.shade100
              : variance > 0
                  ? Colors.blue.shade100
                  : Colors.red.shade100,
          child: Icon(
            variance == 0
                ? Icons.check
                : variance > 0
                    ? Icons.add
                    : Icons.remove,
            color: variance == 0
                ? Colors.green.shade600
                : variance > 0
                    ? Colors.blue.shade600
                    : Colors.red.shade600,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System: ${product.stockQuantity} | Physical: $physicalCount'),
            if (variance != 0)
              Text(
                'Variance: ${variance > 0 ? '+' : ''}$variance',
                style: TextStyle(
                  color:
                      variance > 0 ? Colors.blue.shade600 : Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (notes != null)
              Text(
                'Notes: $notes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            Text(
              barcodeService.formatBarcodeForDisplay(product.barcode),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: variance != 0
            ? Icon(
                Icons.warning,
                color:
                    variance > 0 ? Colors.blue.shade600 : Colors.red.shade600,
              )
            : const Icon(Icons.check, color: Colors.green),
        onTap: onTap,
        isThreeLine: true,
      ),
    );
  }
}
