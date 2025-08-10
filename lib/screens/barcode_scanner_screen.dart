import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/barcode_service.dart';
import '../services/database_helper.dart';
import '../models/product.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String)? onBarcodeScanned;
  final bool returnResult;

  const BarcodeScannerScreen({
    Key? key,
    this.onBarcodeScanned,
    this.returnResult = false,
  }) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController controller;
  String? result;
  bool flashOn = false;
  bool isScanning = true;

  final BarcodeService _barcodeService = BarcodeService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final hasPermission = await _barcodeService.requestCameraPermission();
    if (!hasPermission) {
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'This app needs camera access to scan barcodes. Please grant camera permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(flashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await controller.toggleTorch();
              setState(() {
                flashOn = !flashOn;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (BarcodeCapture capture) {
                    if (isScanning && capture.barcodes.isNotEmpty) {
                      final String? code = capture.barcodes.first.rawValue;
                      if (code != null) {
                        _handleBarcodeScanned(code);
                      }
                    }
                  },
                ),
                if (!isScanning)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (result != null)
                    Column(
                      children: [
                        Text(
                          'Barcode: $result',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type: ${_barcodeService.getBarcodeType(result!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Point camera at a barcode',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBarcodeScanned(String barcode) async {
    setState(() {
      result = barcode;
      isScanning = false;
    });

    await _barcodeService.provideScanFeedback();

    if (!_barcodeService.isValidBarcode(barcode)) {
      _showErrorDialog('Invalid barcode format');
      _resetScanning();
      return;
    }

    if (widget.onBarcodeScanned != null) {
      widget.onBarcodeScanned!(barcode);
    }

    if (widget.returnResult) {
      Navigator.of(context).pop(barcode);
      return;
    }

    // Check if product exists in database
    final product = await _databaseHelper.getProductByBarcode(barcode);

    if (product != null) {
      _showProductDialog(product);
    } else {
      _showAddProductDialog(barcode);
    }
  }

  void _showProductDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Barcode: ${_barcodeService.formatBarcodeForDisplay(product.barcode)}'),
            const SizedBox(height: 8),
            Text('Price: \$${product.price.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Stock: ${product.stockQuantity}'),
            const SizedBox(height: 8),
            Text('Category: ${product.category}'),
            if (product.description != null) ...[
              const SizedBox(height: 8),
              Text('Description: ${product.description}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanning();
            },
            child: const Text('Scan Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(product);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Barcode: ${_barcodeService.formatBarcodeForDisplay(barcode)}'),
            const SizedBox(height: 16),
            const Text(
                'This product is not in your inventory. Would you like to add it?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanning();
            },
            child: const Text('Scan Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.pushNamed(
                context,
                '/add_product',
                arguments: {'barcode': barcode},
              );
            },
            child: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetScanning() {
    setState(() {
      result = null;
      isScanning = true;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
