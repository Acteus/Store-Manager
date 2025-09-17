import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/sale_item.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../core/config/philippines_config.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();

  final List<SaleItem> _cartItems = [];
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isProcessingSale = false;
  String _paymentMethod = 'Cash';
  final double _taxRate = PhilippinesConfig.vatRate; // 12% VAT rate

  final List<String> _paymentMethods = PhilippinesConfig.paymentMethods;

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
      print('POS Screen - Loaded ${products.length} products');
      for (var product in products) {
        print(
            'Product: ${product.name} - ${product.barcode} - ₱${product.price}');
      }
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
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
        return query.isEmpty ||
            product.name.toLowerCase().contains(query) ||
            product.barcode.contains(query) ||
            product.category.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _scanProduct() async {
    final barcode = await Navigator.pushNamed(
      context,
      '/barcode_scanner',
      arguments: {'returnResult': true},
    ) as String?;

    if (barcode != null) {
      final product = await _databaseHelper.getProductByBarcode(barcode);
      if (product != null) {
        _addToCart(product);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found')),
          );
        }
      }
    }
  }

  void _addToCart(Product product, {int quantity = 1}) {
    if (product.stockQuantity < quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient stock for ${product.name}')),
      );
      return;
    }

    setState(() {
      final existingItemIndex = _cartItems.indexWhere(
        (item) => item.productId == product.id,
      );

      if (existingItemIndex >= 0) {
        final existingItem = _cartItems[existingItemIndex];
        final newQuantity = existingItem.quantity + quantity;

        if (product.stockQuantity < newQuantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Insufficient stock for ${product.name}')),
          );
          return;
        }

        _cartItems[existingItemIndex] = existingItem.copyWith(
          quantity: newQuantity,
          totalPrice: product.price * newQuantity,
        );
      } else {
        _cartItems.add(SaleItem(
          id: const Uuid().v4(),
          productId: product.id,
          productName: product.name,
          productBarcode: product.barcode,
          unitPrice: product.price,
          quantity: quantity,
          totalPrice: product.price * quantity,
        ));
      }
    });

    // Check if product will be low stock after this addition
    final remainingStock = product.stockQuantity - quantity;
    if (remainingStock <= product.minStockLevel && remainingStock > 0) {
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        barcode: product.barcode,
        price: product.price,
        category: product.category,
        description: product.description,
        stockQuantity: remainingStock,
        minStockLevel: product.minStockLevel,
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
      );
      _notificationService.showLowStockNotification(context, updatedProduct);
    } else if (remainingStock <= 0) {
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        barcode: product.barcode,
        price: product.price,
        category: product.category,
        description: product.description,
        stockQuantity: remainingStock,
        minStockLevel: product.minStockLevel,
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
      );
      _notificationService.showOutOfStockNotification(context, updatedProduct);
    }
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateCartItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }

    final item = _cartItems[index];
    final product = _products.firstWhere((p) => p.id == item.productId);

    if (product.stockQuantity < newQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient stock for ${product.name}')),
      );
      return;
    }

    setState(() {
      _cartItems[index] = item.copyWith(
        quantity: newQuantity,
        totalPrice: item.unitPrice * newQuantity,
      );
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get _tax {
    return _subtotal * _taxRate;
  }

  double get _total {
    return _subtotal + _tax;
  }

  Future<void> _processSale() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    setState(() {
      _isProcessingSale = true;
    });

    try {
      final sale = Sale(
        id: const Uuid().v4(),
        items: _cartItems,
        subtotal: _subtotal,
        tax: _tax,
        total: _total,
        timestamp: DateTime.now(),
        customerName: _customerController.text.trim().isEmpty
            ? null
            : _customerController.text.trim(),
        paymentMethod: _paymentMethod,
      );

      await _databaseHelper.insertSaleWithItems(sale);

      // Reload products to update stock quantities
      await _loadProducts();

      setState(() {
        _cartItems.clear();
        _customerController.clear();
        _isProcessingSale = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Sale completed: ${PhilippinesConfig.formatCurrency(_total)}')),
        );

        _showReceiptDialog(sale);
      }
    } catch (e) {
      setState(() {
        _isProcessingSale = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing sale: $e')),
        );
      }
    }
  }

  void _showReceiptDialog(Sale sale) {
    final formatter = DateFormat('MMM dd, yyyy HH:mm');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Official Receipt'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Business Header
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Your Business Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Your Business Address'),
                    Text(PhilippinesConfig.vatRegistrationText),
                    Text(PhilippinesConfig.businessPermitText),
                  ],
                ),
              ),
              const Divider(),
              Text('Date: ${formatter.format(sale.timestamp)}'),
              Text('Receipt #: ${sale.id.substring(0, 8)}'),
              if (sale.customerName != null)
                Text('Customer: ${sale.customerName}'),
              Text('Payment Method: ${sale.paymentMethod}'),
              const Divider(),
              // Items
              ...sale.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${item.productName} x${item.quantity}'),
                        ),
                        Text(PhilippinesConfig.formatCurrency(item.totalPrice)),
                      ],
                    ),
                  )),
              const Divider(),
              // Net Amount (VAT Exclusive)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('VAT Exclusive Amount:'),
                  Text(PhilippinesConfig.formatCurrency(
                      PhilippinesConfig.calculateNetFromGross(sale.total))),
                ],
              ),
              // VAT Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${PhilippinesConfig.formatVatText()}:'),
                  Text(PhilippinesConfig.formatCurrency(sale.tax)),
                ],
              ),
              const Divider(),
              // Total (VAT Inclusive)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount (VAT Inclusive):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(PhilippinesConfig.formatCurrency(sale.total),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  PhilippinesConfig.receiptFooter,
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // In a real app, you might integrate with a printer here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt printed (simulated)')),
              );
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanProduct,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _cartItems.isNotEmpty ? _clearCart : null,
          ),
        ],
      ),
      body: Row(
        children: [
          // Products Section (Left Side)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanProduct,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => _filterProducts(),
                  ),
                ),

                // Products Grid
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredProducts.isEmpty
                          ? const Center(
                              child: Text(
                                'No products found',
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return _ProductCard(
                                  product: product,
                                  onTap: () => _addToCart(product),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // Cart Section (Right Side)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  // Cart Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.green.shade50,
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart),
                        const SizedBox(width: 8),
                        Text(
                          'Cart (${_cartItems.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_cartItems.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearCart,
                          ),
                      ],
                    ),
                  ),

                  // Cart Items
                  Expanded(
                    child: _cartItems.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Cart is empty',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              return _CartItem(
                                item: item,
                                onQuantityChanged: (quantity) =>
                                    _updateCartItemQuantity(index, quantity),
                                onRemove: () => _removeFromCart(index),
                              );
                            },
                          ),
                  ),

                  // Payment Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Column(
                      children: [
                        // Customer Name
                        TextField(
                          controller: _customerController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Payment Method
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: _paymentMethods.map((method) {
                            return DropdownMenuItem<String>(
                              value: method,
                              child: Text(method),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // Totals
                        _TotalSection(
                          subtotal: _subtotal,
                          tax: _tax,
                          total: _total,
                          taxRate: _taxRate,
                        ),

                        const SizedBox(height: 16),

                        // Process Sale Button
                        ElevatedButton.icon(
                          onPressed: _cartItems.isEmpty || _isProcessingSale
                              ? null
                              : _processSale,
                          icon: _isProcessingSale
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.payment),
                          label: Text(_isProcessingSale
                              ? 'Processing...'
                              : 'Process Sale'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
    _customerController.dispose();
    super.dispose();
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: product.stockQuantity > 0 ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.inventory_2,
                    size: 48,
                    color: product.isOutOfStock
                        ? Colors.red.shade300
                        : product.isLowStock
                            ? Colors.orange.shade300
                            : Colors.green.shade300,
                  ),
                ),
              ),
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '₱${product.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Stock: ${product.stockQuantity}',
                style: TextStyle(
                  fontSize: 12,
                  color: product.isOutOfStock
                      ? Colors.red.shade600
                      : product.isLowStock
                          ? Colors.orange.shade600
                          : Colors.grey.shade600,
                ),
              ),
              if (product.isOutOfStock)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'OUT OF STOCK',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final SaleItem item;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItem({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => onQuantityChanged(item.quantity - 1),
                ),
                Text(
                  item.quantity.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => onQuantityChanged(item.quantity + 1),
                ),
                const Spacer(),
                Text(
                  '₱${item.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            Text(
              '₱${item.unitPrice.toStringAsFixed(2)} each',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalSection extends StatelessWidget {
  final double subtotal;
  final double tax;
  final double total;
  final double taxRate;

  const _TotalSection({
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.taxRate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:'),
            Text(PhilippinesConfig.formatCurrency(subtotal)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${PhilippinesConfig.formatVatText()}:'),
            Text(PhilippinesConfig.formatCurrency(tax)),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              PhilippinesConfig.formatCurrency(total),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
