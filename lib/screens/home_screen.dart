import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../core/config/philippines_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  int _totalProducts = 0;
  int _lowStockProducts = 0;
  int _outOfStockProducts = 0;
  double _todaysSales = 0.0;
  int _todaysSalesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load products data
      final products = await _databaseHelper.getAllProducts();
      final lowStockProducts = await _databaseHelper.getLowStockProducts();

      // Load today's sales data
      final sales = await _databaseHelper.getAllSales();
      final today = DateTime.now();
      final todaysSales = sales.where((sale) {
        return sale.timestamp.year == today.year &&
            sale.timestamp.month == today.month &&
            sale.timestamp.day == today.day;
      }).toList();

      setState(() {
        _totalProducts = products.length;
        _lowStockProducts = lowStockProducts.length;
        _outOfStockProducts = products.where((p) => p.isOutOfStock).length;
        _todaysSales = todaysSales.fold(0.0, (sum, sale) => sum + sale.total);
        _todaysSalesCount = todaysSales.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS & Inventory System'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.store,
                                  size: 32,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Welcome to your Store',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Today is ${DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now())}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Stats
                    const Text(
                      'Quick Stats',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Products',
                            value: _totalProducts.toString(),
                            icon: Icons.inventory_2,
                            color: Colors.blue,
                            onTap: () =>
                                Navigator.pushNamed(context, '/inventory'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Low Stock',
                            value: _lowStockProducts.toString(),
                            icon: Icons.warning,
                            color: Colors.orange,
                            onTap: () =>
                                Navigator.pushNamed(context, '/inventory'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Out of Stock',
                            value: _outOfStockProducts.toString(),
                            icon: Icons.error,
                            color: Colors.red,
                            onTap: () =>
                                Navigator.pushNamed(context, '/inventory'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: "Today's Sales",
                            value:
                                PhilippinesConfig.formatCurrency(_todaysSales),
                            subtitle: '$_todaysSalesCount transactions',
                            icon: Icons.attach_money,
                            color: Colors.green,
                            onTap: () =>
                                Navigator.pushNamed(context, '/sales_history'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _ActionCard(
                          title: 'Start Sale',
                          subtitle: 'Process transactions',
                          icon: Icons.point_of_sale,
                          color: Colors.green,
                          onTap: () => Navigator.pushNamed(context, '/pos'),
                        ),
                        _ActionCard(
                          title: 'Scan Barcode',
                          subtitle: 'Quick product lookup',
                          icon: Icons.qr_code_scanner,
                          color: Colors.blue,
                          onTap: () =>
                              Navigator.pushNamed(context, '/barcode_scanner'),
                        ),
                        _ActionCard(
                          title: 'Add Product',
                          subtitle: 'New inventory item',
                          icon: Icons.add_box,
                          color: Colors.purple,
                          onTap: () =>
                              Navigator.pushNamed(context, '/add_product'),
                        ),
                        _ActionCard(
                          title: 'Inventory Count',
                          subtitle: 'Physical count check',
                          icon: Icons.inventory,
                          color: Colors.orange,
                          onTap: () =>
                              Navigator.pushNamed(context, '/inventory_count'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // System Features
                    const Text(
                      'System Features',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.inventory_2,
                                color: Colors.blue.shade700),
                            title: const Text('Inventory Management'),
                            subtitle:
                                const Text('Add, edit, and track products'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () =>
                                Navigator.pushNamed(context, '/inventory'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.qr_code,
                                color: Colors.green.shade700),
                            title: const Text('Barcode Generator'),
                            subtitle:
                                const Text('Generate barcodes for products'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => Navigator.pushNamed(
                                context, '/barcode_generator'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.history,
                                color: Colors.purple.shade700),
                            title: const Text('Sales History'),
                            subtitle: const Text('View past transactions'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () =>
                                Navigator.pushNamed(context, '/sales_history'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.analytics,
                                color: Colors.orange.shade700),
                            title: const Text('Reports'),
                            subtitle: const Text('Sales and inventory reports'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () =>
                                Navigator.pushNamed(context, '/reports'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey.shade400),
                ],
              ),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
