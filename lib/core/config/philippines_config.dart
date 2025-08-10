import 'package:intl/intl.dart';

class PhilippinesConfig {
  // Philippine Tax Configuration
  static const double vatRate = 0.12; // 12% VAT as per Philippine law
  static const String vatDisplayName = 'VAT';
  static const String vatFullName = 'Value Added Tax';

  // Currency Configuration
  static const String currencyCode = 'PHP';
  static const String currencySymbol = '₱';
  static const String currencyName = 'Philippine Peso';

  // Number formatting for Philippines
  static final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: currencySymbol,
    decimalDigits: 2,
  );

  // Alternative formatter without symbol (for calculations display)
  static final NumberFormat numberFormatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '',
    decimalDigits: 2,
  );

  // Philippine specific business rules
  static const double maxDiscountPercent =
      20.0; // 20% senior citizen/PWD discount
  static const double maxSingleTransactionAmount =
      50000.0; // ₱50,000 reporting threshold

  // Payment methods common in Philippines
  static const List<String> paymentMethods = [
    'Cash',
    'GCash',
    'Maya',
    'Credit Card',
    'Debit Card',
    'Bank Transfer',
    'Installment',
  ];

  // Format currency for display
  static String formatCurrency(double amount) {
    return currencyFormatter.format(amount);
  }

  // Format currency without symbol
  static String formatNumber(double amount) {
    return numberFormatter.format(amount).trim();
  }

  // Calculate VAT from gross amount (VAT-inclusive)
  static double calculateVatFromGross(double grossAmount) {
    return grossAmount - (grossAmount / (1 + vatRate));
  }

  // Calculate gross amount from net (VAT-exclusive)
  static double calculateGrossFromNet(double netAmount) {
    return netAmount * (1 + vatRate);
  }

  // Calculate net amount from gross (remove VAT)
  static double calculateNetFromGross(double grossAmount) {
    return grossAmount / (1 + vatRate);
  }

  // Format VAT display text
  static String formatVatText() {
    return '$vatDisplayName (${(vatRate * 100).toStringAsFixed(0)}%)';
  }

  // Business hours and locale settings
  static const String locale = 'en_PH';
  static const String timezone = 'Asia/Manila';

  // Receipt footer text
  static const String receiptFooter = 'Thank you for shopping with us!';
  static const String vatRegistrationText = 'VAT Reg. TIN: [Your TIN Here]';
  static const String businessPermitText =
      'Business Permit No: [Your Permit No]';
}
