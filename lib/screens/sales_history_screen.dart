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
      final sales = await _databaseHelper.getAllSalesIncludingVoided();
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'cleanup':
                  _showCleanupDialog();
                  break;
                case 'stats':
                  _showStatsDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cleanup',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services),
                    SizedBox(width: 8),
                    Text('Cleanup Voided Sales'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics),
                    SizedBox(width: 8),
                    Text('Sales Statistics'),
                  ],
                ),
              ),
            ],
          ),
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
                              onVoid: () => _showVoidSaleDialog(sale),
                              onDelete: sale.isVoided
                                  ? () => _showDeleteVoidedSaleDialog(sale)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoidSaleDialog(Sale sale) async {
    if (sale.isVoided) return;

    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to void this sale?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Receipt #${sale.id.substring(0, 8)}'),
            Text('Total: ${PhilippinesConfig.formatCurrency(sale.total)}'),
            const SizedBox(height: 16),
            const Text('Reason for voiding:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter reason (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: This will restore inventory and cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Void Sale'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _databaseHelper.voidSale(sale.id, reasonController.text.trim());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sale #${sale.id.substring(0, 8)} has been voided'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Reload sales to show updated status
        await _loadSales();

        // Notify other screens to refresh by sending a message via Navigator
        // This will trigger a refresh in the home screen when returning
        if (mounted && Navigator.canPop(context)) {
          // We could implement a callback or use state management for this
          // For now, the home screen will refresh when navigating back to it
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to void sale: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteVoidedSaleDialog(Sale sale) async {
    if (!sale.isVoided) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Delete Voided Sale'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to permanently delete this voided sale?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Receipt #${sale.id.substring(0, 8)}'),
            Text('Amount: ${PhilippinesConfig.formatCurrency(sale.total)}'),
            if (sale.voidReason != null) ...[
              const SizedBox(height: 4),
              Text('Void reason: ${sale.voidReason}'),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Important:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• This action cannot be undone\n'
                    '• The sale will be permanently removed\n'
                    '• This helps keep your sales history clean',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deleteVoidedSale(sale.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Sale #${sale.id.substring(0, 8)} permanently deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reload sales to update the list
        await _loadSales();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete sale: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCleanupDialog() async {
    final voidedSales = _sales.where((sale) => sale.isVoided).toList();

    if (voidedSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No voided sales to cleanup'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Cleanup Voided Sales'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found ${voidedSales.length} voided sales that can be cleaned up.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cleanup options:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Delete all voided sales'),
              subtitle:
                  Text('Remove all ${voidedSales.length} voided transactions'),
              onTap: () => Navigator.of(context).pop(true),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Delete old voided sales'),
              subtitle: const Text('Remove voided sales older than 30 days'),
              onTap: () => Navigator.of(context).pop('old'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Note: This action cannot be undone. Voided sales will be permanently removed.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete all voided sales
      try {
        final voidedSaleIds = voidedSales.map((sale) => sale.id).toList();
        await _databaseHelper.deleteMultipleVoidedSales(voidedSaleIds);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${voidedSaleIds.length} voided sales permanently deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadSales();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cleanup sales: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (confirmed == 'old') {
      // Delete old voided sales
      try {
        final deletedCount =
            await _databaseHelper.cleanupOldVoidedSales(olderThanDays: 30);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deletedCount old voided sales deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadSales();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cleanup old sales: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showStatsDialog() async {
    final totalSales = _sales.length;
    final voidedSales = _sales.where((sale) => sale.isVoided).length;
    final activeSales = totalSales - voidedSales;
    final totalRevenue = _sales
        .where((sale) => !sale.isVoided)
        .fold(0.0, (sum, sale) => sum + sale.total);
    final voidedAmount = _sales
        .where((sale) => sale.isVoided)
        .fold(0.0, (sum, sale) => sum + sale.total);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Sales Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Sales', '$totalSales', Icons.receipt_long),
            _buildStatRow('Active Sales', '$activeSales', Icons.check_circle,
                Colors.green),
            _buildStatRow(
                'Voided Sales', '$voidedSales', Icons.cancel, Colors.red),
            const Divider(),
            _buildStatRow(
                'Total Revenue',
                PhilippinesConfig.formatCurrency(totalRevenue),
                Icons.attach_money,
                Colors.green),
            _buildStatRow(
                'Voided Amount',
                PhilippinesConfig.formatCurrency(voidedAmount),
                Icons.money_off,
                Colors.red),
            const SizedBox(height: 8),
            if (voidedSales > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tip: Use "Cleanup Voided Sales" to remove old voided transactions and keep your sales history clean.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon,
      [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
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
  final VoidCallback? onVoid;
  final VoidCallback? onDelete;

  const _SaleListItem({
    required this.sale,
    required this.onTap,
    this.onVoid,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM dd, HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: sale.isVoided ? Colors.red.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              sale.isVoided ? Colors.red.shade100 : Colors.green.shade100,
          child: Icon(
            sale.isVoided ? Icons.cancel : Icons.receipt,
            color: sale.isVoided ? Colors.red.shade700 : Colors.green.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Receipt #${sale.id.substring(0, 8)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (sale.isVoided)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VOIDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatter.format(sale.timestamp)),
            Text('${sale.items.length} items • ${sale.paymentMethod}'),
            if (sale.customerName != null)
              Text('Customer: ${sale.customerName}'),
            if (sale.isVoided && sale.voidReason != null)
              Text(
                'Void reason: ${sale.voidReason}',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
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
                color:
                    sale.isVoided ? Colors.red.shade700 : Colors.green.shade700,
                decoration: sale.isVoided ? TextDecoration.lineThrough : null,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!sale.isVoided && onVoid != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: GestureDetector(
                      onTap: onVoid,
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                if (sale.isVoided && onDelete != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.delete_forever,
                        size: 20,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ],
        ),
        onTap: onTap,
        isThreeLine: sale.customerName != null,
      ),
    );
  }
}
