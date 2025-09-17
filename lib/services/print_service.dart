import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/product.dart';

class PrintService {
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  /// Print a single barcode for a product
  Future<void> printProductBarcode(Product product) async {
    try {
      final pdf = await _generateProductBarcodePdf(product);

      // Try direct printing first
      if (await _canPrint()) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name:
              'barcode_${product.name.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf',
        );
      } else {
        // Fallback to sharing PDF
        await _shareGeneratedPdf(pdf,
            'barcode_${product.name.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf');
      }
    } catch (e) {
      // If direct printing fails, try sharing as fallback
      try {
        final pdf = await _generateProductBarcodePdf(product);
        await _shareGeneratedPdf(pdf,
            'barcode_${product.name.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf');
      } catch (shareError) {
        throw Exception(
            'Failed to print or share barcode: $e. Share error: $shareError');
      }
    }
  }

  /// Print multiple barcodes for a list of products
  Future<void> printMultipleBarcodes(List<Product> products) async {
    try {
      final pdf = await _generateMultipleBarcodePdf(products);

      if (await _canPrint()) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'multiple_barcodes.pdf',
        );
      } else {
        await _shareGeneratedPdf(pdf, 'multiple_barcodes.pdf');
      }
    } catch (e) {
      // Fallback to sharing
      try {
        final pdf = await _generateMultipleBarcodePdf(products);
        await _shareGeneratedPdf(pdf, 'multiple_barcodes.pdf');
      } catch (shareError) {
        throw Exception(
            'Failed to print or share multiple barcodes: $e. Share error: $shareError');
      }
    }
  }

  /// Print just a barcode without product information
  Future<void> printBarcode(String barcodeData, {String? productName}) async {
    try {
      final pdf =
          await _generateBarcodePdf(barcodeData, productName: productName);

      if (await _canPrint()) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'barcode_$barcodeData.pdf',
        );
      } else {
        await _shareGeneratedPdf(pdf, 'barcode_$barcodeData.pdf');
      }
    } catch (e) {
      // Fallback to sharing
      try {
        final pdf =
            await _generateBarcodePdf(barcodeData, productName: productName);
        await _shareGeneratedPdf(pdf, 'barcode_$barcodeData.pdf');
      } catch (shareError) {
        throw Exception(
            'Failed to print or share barcode: $e. Share error: $shareError');
      }
    }
  }

  /// Generate PDF for a single product barcode
  Future<pw.Document> _generateProductBarcodePdf(Product product) async {
    final pdf = pw.Document();

    // Determine the best barcode type for the data
    final barcodeType = _getBarcodeType(product.barcode);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Text(
                  'Product Barcode',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              // Product information
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      product.name,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Category: ${product.category}'),
                    pw.Text('Price: ₱${product.price.toStringAsFixed(2)}'),
                    pw.Text('Stock: ${product.stockQuantity}'),
                    if (product.description != null &&
                        product.description!.isNotEmpty)
                      pw.Text('Description: ${product.description!}'),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Barcode section
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.BarcodeWidget(
                      barcode: barcodeType,
                      data: product.barcode,
                      width: 300,
                      height: 80,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      product.barcode,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 20),
                child: pw.Text(
                  'Generated on: ${DateTime.now().toString().split('.')[0]}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Generate PDF for multiple product barcodes
  Future<pw.Document> _generateMultipleBarcodePdf(
      List<Product> products) async {
    final pdf = pw.Document();
    const int itemsPerPage = 12; // 3x4 grid

    for (int i = 0; i < products.length; i += itemsPerPage) {
      final pageProducts = products.skip(i).take(itemsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 20),
                  child: pw.Text(
                    'Product Barcodes (Page ${(i ~/ itemsPerPage) + 1})',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                // Grid of barcodes
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: pageProducts.map((product) {
                      final barcodeType = _getBarcodeType(product.barcode);
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              product.name,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: pw.TextOverflow.clip,
                            ),
                            pw.SizedBox(height: 4),
                            pw.BarcodeWidget(
                              barcode: barcodeType,
                              data: product.barcode,
                              width: 120,
                              height: 40,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              product.barcode,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                            pw.Text(
                              '₱${product.price.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Generated on: ${DateTime.now().toString().split('.')[0]}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  /// Generate PDF for a simple barcode
  Future<pw.Document> _generateBarcodePdf(String barcodeData,
      {String? productName}) async {
    final pdf = pw.Document();
    final barcodeType = _getBarcodeType(barcodeData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(30),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (productName != null) ...[
                    pw.Text(
                      productName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                  pw.BarcodeWidget(
                    barcode: barcodeType,
                    data: barcodeData,
                    width: 400,
                    height: 100,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    barcodeData,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf;
  }

  /// Determine the best barcode type based on the data
  Barcode _getBarcodeType(String data) {
    // Remove whitespace
    data = data.trim();

    // Check for specific barcode formats
    if (RegExp(r'^\d{13}$').hasMatch(data)) {
      return Barcode.ean13();
    } else if (RegExp(r'^\d{12}$').hasMatch(data)) {
      return Barcode.upcA();
    } else if (RegExp(r'^\d{8}$').hasMatch(data)) {
      return Barcode.ean8();
    } else if (RegExp(r'^[0-9A-Z\-. $\/+%]+$').hasMatch(data)) {
      return Barcode.code39();
    } else {
      // Default to Code128 for most other cases
      return Barcode.code128();
    }
  }

  /// Check if printing is available and working
  Future<bool> _canPrint() async {
    try {
      // On mobile platforms, printing might not be available
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // For mobile, try to access printing info
        await Printing.info();
        return true;
      }
      // For desktop platforms, assume printing is available
      return true;
    } catch (e) {
      // If there's any error accessing printing, return false
      if (kDebugMode) {
        print('Printing not available: $e');
      }
      return false;
    }
  }

  /// Share a generated PDF using the platform's sharing mechanism
  Future<void> _shareGeneratedPdf(pw.Document pdf, String filename) async {
    try {
      final bytes = await pdf.save();

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // For mobile platforms, use share_plus
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Barcode PDF',
        );
      } else {
        // For desktop platforms, fall back to the printing package's share
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );
      }
    } catch (e) {
      throw Exception('Failed to share PDF: $e');
    }
  }

  /// Check if printing is available on the device
  Future<bool> isPrintingAvailable() async {
    return await _canPrint();
  }

  /// Get available printers
  Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      return [];
    }
  }

  /// Print to a specific printer
  Future<void> printToSpecificPrinter(
    Printer printer,
    pw.Document pdf, {
    String? jobName,
  }) async {
    try {
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: jobName ?? 'Barcode Print Job',
      );
    } catch (e) {
      throw Exception('Failed to print to specific printer: $e');
    }
  }

  /// Share the barcode PDF instead of printing
  Future<void> shareBarcodeAsPdf(String barcodeData,
      {String? productName}) async {
    try {
      final pdf =
          await _generateBarcodePdf(barcodeData, productName: productName);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'barcode_${barcodeData}.pdf',
      );
    } catch (e) {
      throw Exception('Failed to share barcode PDF: $e');
    }
  }
}
