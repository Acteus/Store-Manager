import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeService {
  static final BarcodeService _instance = BarcodeService._internal();
  factory BarcodeService() => _instance;
  BarcodeService._internal();

  // Check and request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Guide user to app settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  // Validate barcode format (basic validation)
  bool isValidBarcode(String barcode) {
    if (barcode.isEmpty) return false;

    // Remove any whitespace
    barcode = barcode.trim();

    // Check for common barcode formats
    if (RegExp(r'^\d{8}$').hasMatch(barcode)) return true; // EAN-8
    if (RegExp(r'^\d{12}$').hasMatch(barcode)) return true; // UPC-A
    if (RegExp(r'^\d{13}$').hasMatch(barcode)) return true; // EAN-13
    if (RegExp(r'^\d{14}$').hasMatch(barcode)) return true; // ITF-14
    if (RegExp(r'^[0-9A-Z\-. $\/+%]+$').hasMatch(barcode))
      return true; // Code 39
    if (RegExp(r'^[0-9]+$').hasMatch(barcode) && barcode.length >= 6)
      return true; // Generic numeric

    return barcode.length >= 4; // Minimum length for custom barcodes
  }

  // Generate a simple barcode for new products
  String generateBarcode() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();

    // Take last 12 digits to create a unique barcode
    String barcode = timestamp.substring(timestamp.length - 12);

    // Ensure it starts with '2' to indicate internal/store-generated
    barcode = '2$barcode';

    return barcode.substring(0, 13); // EAN-13 format
  }

  // Validate EAN-13 checksum
  bool validateEAN13(String barcode) {
    if (barcode.length != 13) return false;

    try {
      List<int> digits = barcode.split('').map((e) => int.parse(e)).toList();

      int sum = 0;
      for (int i = 0; i < 12; i++) {
        if (i % 2 == 0) {
          sum += digits[i];
        } else {
          sum += digits[i] * 3;
        }
      }

      int checkDigit = (10 - (sum % 10)) % 10;
      return checkDigit == digits[12];
    } catch (e) {
      return false;
    }
  }

  // Format barcode for display
  String formatBarcodeForDisplay(String barcode) {
    if (barcode.length == 13) {
      // EAN-13 format: 1 234567 890123
      return '${barcode.substring(0, 1)} ${barcode.substring(1, 7)} ${barcode.substring(7, 13)}';
    } else if (barcode.length == 12) {
      // UPC-A format: 123456 789012
      return '${barcode.substring(0, 6)} ${barcode.substring(6, 12)}';
    } else if (barcode.length == 8) {
      // EAN-8 format: 1234 5678
      return '${barcode.substring(0, 4)} ${barcode.substring(4, 8)}';
    }

    return barcode; // Return as-is for other formats
  }

  // Provide haptic feedback for successful scan
  Future<void> provideScanFeedback() async {
    await HapticFeedback.mediumImpact();
  }

  // Get barcode type based on format
  String getBarcodeType(String barcode) {
    if (barcode.length == 8) return 'EAN-8';
    if (barcode.length == 12) return 'UPC-A';
    if (barcode.length == 13) return 'EAN-13';
    if (barcode.length == 14) return 'ITF-14';
    if (RegExp(r'^[0-9A-Z\-. $\/+%]+$').hasMatch(barcode)) return 'Code 39';
    if (RegExp(r'^[0-9]+$').hasMatch(barcode)) return 'Numeric';
    return 'Custom';
  }
}
