import 'package:dartz/dartz.dart';
import '../error/failures.dart';
import '../config/philippines_config.dart';
import '../../models/product.dart';
import '../../models/sale_item.dart';

// Pricing business logic
class PricingService {
  static const double defaultTaxRate = PhilippinesConfig.vatRate; // 12% VAT
  static const double maxDiscountPercent = PhilippinesConfig.maxDiscountPercent;

  // Calculate sale totals (VAT already included in item prices)
  SaleCalculation calculateSaleTotal(
    List<SaleItem> items, {
    double taxRate = 0.0, // VAT already included in prices
    double discountPercent = 0.0,
    double discountAmount = 0.0,
  }) {
    if (items.isEmpty) {
      return SaleCalculation(
        subtotal: 0.0,
        discount: 0.0,
        tax: 0.0,
        total: 0.0,
        items: [],
      );
    }

    final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);

    // Calculate discount
    double discount = 0.0;
    if (discountPercent > 0) {
      discount = subtotal * (discountPercent / 100);
    } else if (discountAmount > 0) {
      discount = discountAmount;
    }

    // Ensure discount doesn't exceed subtotal
    discount = discount > subtotal ? subtotal : discount;

    final discountedSubtotal = subtotal - discount;
    final tax = 0.0; // VAT already included in item prices
    final total = discountedSubtotal; // No additional tax to add

    return SaleCalculation(
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      items: items,
    );
  }

  // Validate discount
  Result<double> validateDiscount(double discount, double subtotal) {
    if (discount < 0) {
      return const Left(ValidationFailure('Discount cannot be negative'));
    }

    if (discount > subtotal) {
      return const Left(ValidationFailure('Discount cannot exceed subtotal'));
    }

    final discountPercent = (discount / subtotal) * 100;
    if (discountPercent > maxDiscountPercent) {
      return Left(
          ValidationFailure('Discount cannot exceed $maxDiscountPercent%'));
    }

    return Right(discount);
  }

  // Calculate item profit margin
  double calculateProfitMargin(double sellingPrice, double costPrice) {
    if (costPrice <= 0) return 0.0;
    return ((sellingPrice - costPrice) / costPrice) * 100;
  }

  // Calculate markup
  double calculateMarkup(double costPrice, double markupPercent) {
    return costPrice * (1 + (markupPercent / 100));
  }
}

// Inventory business logic
class InventoryService {
  // Check if product is in stock
  bool isInStock(Product product, int requestedQuantity) {
    return product.stockQuantity >= requestedQuantity;
  }

  // Check if product is low stock
  bool isLowStock(Product product) {
    return product.stockQuantity <= product.minStockLevel;
  }

  // Calculate reorder quantity
  int calculateReorderQuantity(Product product, {int? targetStock}) {
    final target = targetStock ?? (product.minStockLevel * 3);
    return target - product.stockQuantity;
  }

  // Validate stock adjustment
  Result<int> validateStockAdjustment(Product product, int adjustment) {
    final newQuantity = product.stockQuantity + adjustment;

    if (newQuantity < 0) {
      return Left(ValidationFailure(
          'Stock adjustment would result in negative inventory'));
    }

    if (newQuantity > 999999) {
      return const Left(ValidationFailure('Stock quantity too large'));
    }

    return Right(newQuantity);
  }

  // Calculate inventory value
  double calculateInventoryValue(List<Product> products) {
    return products.fold(
        0.0, (sum, product) => sum + (product.price * product.stockQuantity));
  }

  // Get ABC analysis classification
  ABCClass classifyProduct(Product product, double salesVolume) {
    // Simplified ABC analysis based on sales volume
    if (salesVolume >= 1000) return ABCClass.A;
    if (salesVolume >= 500) return ABCClass.B;
    return ABCClass.C;
  }
}

// Sales business logic
class SalesService {
  // Validate sale before processing
  Result<void> validateSale(List<SaleItem> items, List<Product> products) {
    if (items.isEmpty) {
      return const Left(
          ValidationFailure('Sale must contain at least one item'));
    }

    for (final item in items) {
      // Find corresponding product
      final product = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => throw StateError('Product not found'),
      );

      // Check stock availability
      if (!InventoryService().isInStock(product, item.quantity)) {
        return Left(ValidationFailure(
            'Insufficient stock for ${product.name}. Available: ${product.stockQuantity}, Requested: ${item.quantity}'));
      }

      // Validate item pricing
      if (item.unitPrice != product.price) {
        return Left(ValidationFailure(
            'Price mismatch for ${product.name}. Expected: ${product.price}, Got: ${item.unitPrice}'));
      }

      // Validate calculated total
      final expectedTotal = item.unitPrice * item.quantity;
      if ((item.totalPrice - expectedTotal).abs() > 0.01) {
        return Left(ValidationFailure(
            'Total price calculation error for ${product.name}'));
      }
    }

    return const Right(null);
  }

  // Calculate commission
  double calculateCommission(double salesAmount, double commissionRate) {
    return salesAmount * (commissionRate / 100);
  }

  // Determine sales performance
  SalesPerformance analyzeSalesPerformance(
    double currentPeriodSales,
    double previousPeriodSales,
  ) {
    if (previousPeriodSales == 0) {
      return SalesPerformance.noData;
    }

    final growthRate =
        ((currentPeriodSales - previousPeriodSales) / previousPeriodSales) *
            100;

    if (growthRate >= 10) return SalesPerformance.excellent;
    if (growthRate >= 5) return SalesPerformance.good;
    if (growthRate >= 0) return SalesPerformance.average;
    if (growthRate >= -5) return SalesPerformance.belowAverage;
    return SalesPerformance.poor;
  }
}

// Barcode business logic
class BarcodeService {
  // Validate barcode format
  Result<String> validateBarcode(String barcode) {
    if (barcode.isEmpty) {
      return const Left(ValidationFailure('Barcode cannot be empty'));
    }

    // Remove any non-digit characters
    final cleanBarcode = barcode.replaceAll(RegExp(r'[^\d]'), '');

    // Check length (common barcode lengths: 8, 12, 13, 14)
    if (![8, 12, 13, 14].contains(cleanBarcode.length)) {
      return const Left(
          ValidationFailure('Barcode must be 8, 12, 13, or 14 digits long'));
    }

    // Validate EAN-13 checksum if it's 13 digits
    if (cleanBarcode.length == 13) {
      if (!_validateEAN13Checksum(cleanBarcode)) {
        return const Left(ValidationFailure('Invalid EAN-13 checksum'));
      }
    }

    return Right(cleanBarcode);
  }

  // Generate EAN-13 barcode
  String generateEAN13Barcode(String prefix) {
    // Ensure prefix is 12 digits
    String code = prefix.padRight(12, '0').substring(0, 12);

    // Calculate check digit
    int checkDigit = _calculateEAN13CheckDigit(code);

    return code + checkDigit.toString();
  }

  // Validate EAN-13 checksum
  bool _validateEAN13Checksum(String barcode) {
    if (barcode.length != 13) return false;

    final code = barcode.substring(0, 12);
    final checkDigit = int.tryParse(barcode.substring(12, 13));
    if (checkDigit == null) return false;

    final calculatedCheckDigit = _calculateEAN13CheckDigit(code);
    return checkDigit == calculatedCheckDigit;
  }

  // Calculate EAN-13 check digit
  int _calculateEAN13CheckDigit(String code) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(code[i]);
      sum += digit * (i % 2 == 0 ? 1 : 3);
    }
    return (10 - (sum % 10)) % 10;
  }
}

// Data classes
class SaleCalculation {
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final List<SaleItem> items;

  SaleCalculation({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.items,
  });
}

enum ABCClass { A, B, C }

enum SalesPerformance {
  excellent,
  good,
  average,
  belowAverage,
  poor,
  noData,
}

// Customer business logic
class CustomerService {
  // Validate customer data
  Result<void> validateCustomerData(Map<String, dynamic> customerData) {
    final name = customerData['name'] as String?;
    final email = customerData['email'] as String?;
    final phone = customerData['phone'] as String?;

    if (name == null || name.trim().isEmpty) {
      return const Left(ValidationFailure('Customer name is required'));
    }

    if (name.trim().length < 2) {
      return const Left(
          ValidationFailure('Customer name must be at least 2 characters'));
    }

    if (email != null && email.isNotEmpty) {
      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email)) {
        return const Left(ValidationFailure('Invalid email format'));
      }
    }

    if (phone != null && phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanPhone.length < 10) {
        return const Left(
            ValidationFailure('Phone number must be at least 10 digits'));
      }
    }

    return const Right(null);
  }

  // Calculate customer loyalty points
  int calculateLoyaltyPoints(double purchaseAmount,
      {double pointsPerDollar = 1.0}) {
    return (purchaseAmount * pointsPerDollar).floor();
  }

  // Determine customer tier
  CustomerTier determineCustomerTier(double totalSpent) {
    if (totalSpent >= 10000) return CustomerTier.platinum;
    if (totalSpent >= 5000) return CustomerTier.gold;
    if (totalSpent >= 1000) return CustomerTier.silver;
    return CustomerTier.bronze;
  }
}

enum CustomerTier { bronze, silver, gold, platinum }
