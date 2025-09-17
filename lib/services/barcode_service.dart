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
    if (RegExp(r'^[0-9A-Z\-. $\/+%]+$').hasMatch(barcode)) {
      return true; // Code 39
    }
    if (RegExp(r'^[0-9]+$').hasMatch(barcode) && barcode.length >= 6) {
      return true; // Generic numeric
    }

    return barcode.length >= 4; // Minimum length for custom barcodes
  }

  // Generate a simple barcode for new products
  String generateBarcode() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();

    // Take last 11 digits to create a unique barcode (we need 12 digits for EAN-13)
    String barcode = timestamp.substring(timestamp.length - 11);

    // Ensure it starts with '2' to indicate internal/store-generated
    barcode = '2$barcode';

    // Calculate and append EAN-13 checksum
    barcode = _generateEAN13WithChecksum(barcode);

    return barcode; // Valid EAN-13 format with checksum
  }

  // Generate valid EAN-13 barcode with correct checksum
  String _generateEAN13WithChecksum(String first12Digits) {
    if (first12Digits.length != 12) {
      throw ArgumentError(
          'Must provide exactly 12 digits for EAN-13 generation');
    }

    List<int> digits =
        first12Digits.split('').map((e) => int.parse(e)).toList();

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      if (i % 2 == 0) {
        sum += digits[i];
      } else {
        sum += digits[i] * 3;
      }
    }

    int checkDigit = (10 - (sum % 10)) % 10;
    return first12Digits + checkDigit.toString();
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

  // Fix invalid EAN-13 barcode by correcting the checksum
  String fixEAN13Checksum(String barcode) {
    if (barcode.length != 13) {
      throw ArgumentError('Barcode must be 13 digits for EAN-13 fix');
    }

    // Take first 12 digits and recalculate checksum
    String first12 = barcode.substring(0, 12);
    return _generateEAN13WithChecksum(first12);
  }

  // Check if barcode is valid for specific barcode type (including checksum validation)
  bool isValidForBarcodeType(String barcode, String type) {
    switch (type) {
      case 'EAN13':
        return barcode.length == 13 &&
            RegExp(r'^\d{13}$').hasMatch(barcode) &&
            validateEAN13(barcode);
      case 'EAN8':
        return barcode.length == 8 && RegExp(r'^\d{8}$').hasMatch(barcode);
      case 'UPC-A':
        return barcode.length == 12 && RegExp(r'^\d{12}$').hasMatch(barcode);
      case 'Code39':
        return RegExp(r'^[0-9A-Z\-. $\/+%]+$').hasMatch(barcode);
      case 'Code128':
        return barcode.isNotEmpty;
      default:
        return false;
    }
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
