import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../services/barcode_service.dart';
import '../services/database_helper.dart';
import '../services/print_service.dart';
import '../models/product.dart';

class BarcodeGeneratorScreen extends StatefulWidget {
  final Product? product;

  const BarcodeGeneratorScreen({Key? key, this.product}) : super(key: key);

  @override
  State<BarcodeGeneratorScreen> createState() => _BarcodeGeneratorScreenState();
}

class _BarcodeGeneratorScreenState extends State<BarcodeGeneratorScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final BarcodeService _barcodeService = BarcodeService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final PrintService _printService = PrintService();

  String selectedBarcodeType = 'EAN13';
  bool isCustomBarcode = false;
  Product? currentProduct;

  final Map<String, Barcode> barcodeTypes = {
    'EAN13': Barcode.ean13(),
    'EAN8': Barcode.ean8(),
    'Code39': Barcode.code39(),
    'Code128': Barcode.code128(),
    'UPC-A': Barcode.upcA(),
  };

  @override
  void initState() {
    super.initState();
    currentProduct = widget.product;

    if (currentProduct != null) {
      _barcodeController.text = currentProduct!.barcode;
    } else {
      _generateNewBarcode();
    }
  }

  void _generateNewBarcode() {
    final newBarcode = _barcodeService.generateBarcode();
    setState(() {
      _barcodeController.text = newBarcode;
      isCustomBarcode = false;
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _barcodeController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Barcode copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _isValidBarcodeForType(String barcode, String type) {
    return _barcodeService.isValidForBarcodeType(barcode, type);
  }

  void _fixEAN13Checksum() {
    if (selectedBarcodeType == 'EAN13' &&
        _barcodeController.text.length == 13 &&
        RegExp(r'^\d{13}$').hasMatch(_barcodeController.text)) {
      try {
        final fixedBarcode =
            _barcodeService.fixEAN13Checksum(_barcodeController.text);
        setState(() {
          _barcodeController.text = fixedBarcode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EAN-13 checksum fixed'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fixing checksum: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _printBarcode() async {
    if (_barcodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a barcode to print')),
      );
      return;
    }

    if (!_isValidBarcodeForType(_barcodeController.text, selectedBarcodeType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid barcode for $selectedBarcodeType')),
      );
      return;
    }

    try {
      if (currentProduct != null) {
        // Print with product information
        await _printService.printProductBarcode(currentProduct!);
      } else {
        // Print just the barcode
        await _printService.printBarcode(_barcodeController.text);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barcode processed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print barcode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareBarcode() async {
    if (_barcodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a barcode to share')),
      );
      return;
    }

    if (!_isValidBarcodeForType(_barcodeController.text, selectedBarcodeType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid barcode for $selectedBarcodeType')),
      );
      return;
    }

    try {
      final productName = currentProduct?.name;
      await _printService.shareBarcodeAsPdf(
        _barcodeController.text,
        productName: productName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share barcode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBarcodeWidget() {
    final barcode = _barcodeController.text;

    if (barcode.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter barcode to preview',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isValidBarcodeForType(barcode, selectedBarcodeType)) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Invalid barcode for $selectedBarcodeType',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 14,
                ),
              ),
              if (selectedBarcodeType == 'EAN13' &&
                  barcode.length == 13 &&
                  RegExp(r'^\d{13}$').hasMatch(barcode)) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _fixEAN13Checksum,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Fix Checksum'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    try {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: BarcodeWidget(
          barcode: barcodeTypes[selectedBarcodeType]!,
          data: barcode,
          width: double.infinity,
          height: 80,
          drawText: true,
          style: const TextStyle(fontSize: 12),
        ),
      );
    } catch (e) {
      // Check if it's a checksum error for EAN-13
      bool isChecksumError = e.toString().contains('checksum') ||
          e.toString().contains('should be');

      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber,
                size: 48,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                isChecksumError
                    ? 'Invalid EAN-13 checksum'
                    : 'Error generating barcode',
                style: TextStyle(
                  color: Colors.orange.shade600,
                  fontSize: 14,
                ),
              ),
              if (isChecksumError && selectedBarcodeType == 'EAN13') ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _fixEAN13Checksum,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Fix Checksum'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  Future<void> _saveProduct() async {
    if (_barcodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a barcode')),
      );
      return;
    }

    if (!_isValidBarcodeForType(_barcodeController.text, selectedBarcodeType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid barcode for $selectedBarcodeType')),
      );
      return;
    }

    // Check if barcode already exists
    final existingProduct =
        await _databaseHelper.getProductByBarcode(_barcodeController.text);
    if (existingProduct != null && existingProduct.id != currentProduct?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Barcode already exists for another product')),
      );
      return;
    }

    if (currentProduct != null) {
      // Update existing product with new barcode
      final updatedProduct = currentProduct!.copyWith(
        barcode: _barcodeController.text,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateProduct(updatedProduct);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product barcode updated successfully')),
        );
        Navigator.of(context).pop(updatedProduct);
      }
    } else {
      // Navigate to add product screen with the generated barcode
      Navigator.pushNamed(
        context,
        '/add_product',
        arguments: {'barcode': _barcodeController.text},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            currentProduct != null ? 'Product Barcode' : 'Generate Barcode'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copy to clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareBarcode,
            tooltip: 'Share as PDF',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printBarcode,
            tooltip: 'Print barcode',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (currentProduct != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentProduct!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Price: ₱${currentProduct!.price.toStringAsFixed(2)}'),
                      Text('Category: ${currentProduct!.category}'),
                      Text('Stock: ${currentProduct!.stockQuantity}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Barcode Type:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        DropdownButton<String>(
                          value: selectedBarcodeType,
                          items: barcodeTypes.keys.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedBarcodeType = newValue;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Barcode',
                        hintText: 'Enter or generate barcode',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _generateNewBarcode,
                              tooltip: 'Generate new barcode',
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _barcodeController.clear();
                                setState(() {});
                              },
                              tooltip: 'Clear',
                            ),
                          ],
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          isCustomBarcode = true;
                        });
                      },
                    ),
                    if (_barcodeController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Type: ${_barcodeService.getBarcodeType(_barcodeController.text)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_barcodeService
                          .validateEAN13(_barcodeController.text))
                        Text(
                          'Valid EAN-13 checksum ✓',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Barcode Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBarcodeWidget(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveProduct,
              icon: Icon(currentProduct != null ? Icons.save : Icons.add),
              label: Text(
                  currentProduct != null ? 'Update Barcode' : 'Create Product'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            if (currentProduct == null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/barcode_scanner');
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Existing Barcode'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }
}
