import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale_item.dart';
import '../services/database_helper.dart';
import '../core/config/philippines_config.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<Sale> _sales = [];
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  String _selectedPeriod = 'All Time';

  final List<String> _periods = [
    'All Time',
    'Today',
    'This Week',
    'This Month'
  ];

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sales = await _databaseHelper.getAllSales();
      setState(() {
        _sales = sales;
        _isLoading = false;
      });
      _filterSales();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales: $e')),
        );
      }
    }
  }

  void _filterSales() {
    final now = DateTime.now();
    List<Sale> filteredSales = [];

    switch (_selectedPeriod) {
      case 'Today':
        filteredSales = _sales.where((sale) {
          return sale.timestamp.year == now.year &&
              sale.timestamp.month == now.month &&
              sale.timestamp.day == now.day;
        }).toList();
        break;
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        filteredSales = _sales.where((sale) {
          return sale.timestamp
                  .isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              sale.timestamp.isBefore(endOfWeek.add(const Duration(days: 1)));
        }).toList();
        break;
      case 'This Month':
        filteredSales = _sales.where((sale) {
          return sale.timestamp.year == now.year &&
              sale.timestamp.month == now.month;
        }).toList();
        break;
      default:
        if (_selectedDateRange != null) {
          filteredSales = _sales.where((sale) {
            return sale.timestamp.isAfter(_selectedDateRange!.start
                    .subtract(const Duration(days: 1))) &&
                sale.timestamp.isBefore(
                    _selectedDateRange!.end.add(const Duration(days: 1)));
          }).toList();
        } else {
          filteredSales = _sales;
        }
    }

    setState(() {
      _sales = filteredSales;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedPeriod = 'Custom Range';
      });
      await _loadSales(); // Reload all sales first
      _filterSales();
    }
  }

  double get _totalSales {
    return _sales.fold(0.0, (sum, sale) => sum + sale.total);
  }

  int get _totalTransactions {
    return _sales.length;
  }

  double get _averageTransaction {
    return _totalTransactions > 0 ? _totalSales / _totalTransactions : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Period: '),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        isExpanded: true,
                        items: [
                          ..._periods,
                          if (_selectedDateRange != null) 'Custom Range'
                        ].map((period) {
                          return DropdownMenuItem<String>(
                            value: period,
                            child: Text(period),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPeriod = value!;
                            if (value != 'Custom Range') {
                              _selectedDateRange = null;
                            }
                          });
                          _loadSales().then((_) => _filterSales());
                        },
                      ),
                    ),
                    if (_selectedPeriod == 'Custom Range')
                      IconButton(
                        icon: const Icon(Icons.edit_calendar),
                        onPressed: _selectDateRange,
                      ),
                  ],
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'From: ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - '
                    'To: ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Summary Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Sales',
                    value: PhilippinesConfig.formatCurrency(_totalSales),
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Transactions',
                    value: _totalTransactions.toString(),
                    icon: Icons.receipt,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Average',
                    value:
                        PhilippinesConfig.formatCurrency(_averageTransaction),
                    icon: Icons.trending_up,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          // Sales List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sales found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sales will appear here once you complete transactions',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSales,
                        child: ListView.builder(
                          itemCount: _sales.length,
                          itemBuilder: (context, index) {
                            final sale = _sales[index];
                            return _SaleListItem(
                              sale: sale,
                              onTap: () => _showSaleDetails(sale),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showSaleDetails(Sale sale) {
    final formatter = DateFormat('MMM dd, yyyy HH:mm');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Receipt #: ${sale.id.substring(0, 8)}'),
              Text('Date: ${formatter.format(sale.timestamp)}'),
              if (sale.customerName != null)
                Text('Customer: ${sale.customerName}'),
              Text('Payment: ${sale.paymentMethod}'),
              const Divider(),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:'),
                  Text(PhilippinesConfig.formatCurrency(sale.subtotal)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${PhilippinesConfig.vatDisplayName}:'),
                  Text(PhilippinesConfig.formatCurrency(sale.tax)),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(PhilippinesConfig.formatCurrency(sale.total),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
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
        ),
      ),
    );
  }
}

class _SaleListItem extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;

  const _SaleListItem({
    required this.sale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM dd, HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(
            Icons.receipt,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(
          'Receipt #${sale.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatter.format(sale.timestamp)),
            Text('${sale.items.length} items • ${sale.paymentMethod}'),
            if (sale.customerName != null)
              Text('Customer: ${sale.customerName}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              PhilippinesConfig.formatCurrency(sale.total),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: onTap,
        isThreeLine: sale.customerName != null,
      ),
    );
  }
}
