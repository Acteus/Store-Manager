import 'package:dartz/dartz.dart';
import '../error/failures.dart';

class InputSanitizer {
  // HTML and script injection prevention
  static const List<String> _dangerousPatterns = [
    '<script',
    '</script>',
    'javascript:',
    'vbscript:',
    'onload=',
    'onerror=',
    'onclick=',
    'onmouseover=',
    'data:text/html',
    'data:application/',
    'eval(',
    'expression(',
    'url(',
    'import(',
    '&lt;script',
    '&gt;',
    '&#',
    'alert(',
    'confirm(',
    'prompt(',
  ];

  static const List<String> _sqlInjectionPatterns = [
    'select ',
    'insert ',
    'update ',
    'delete ',
    'drop ',
    'create ',
    'alter ',
    'exec ',
    'execute ',
    'union ',
    'or 1=1',
    'or true',
    "' or '",
    '" or "',
    '--',
    '/*',
    '*/',
    'xp_',
    'sp_',
  ];

  // Sanitize text input
  static Result<String> sanitizeText(
    String input, {
    int? maxLength,
    bool allowHtml = false,
    bool allowSpecialChars = true,
  }) {
    if (input.isEmpty) {
      return const Right('');
    }

    String sanitized = input.trim();

    // Check length
    if (maxLength != null && sanitized.length > maxLength) {
      return Left(
          ValidationFailure('Input too long. Maximum $maxLength characters.'));
    }

    // Remove dangerous patterns
    if (!allowHtml) {
      for (final pattern in _dangerousPatterns) {
        if (sanitized.toLowerCase().contains(pattern.toLowerCase())) {
          return Left(ValidationFailure(
              'Input contains potentially dangerous content.'));
        }
      }
    }

    // Check for SQL injection attempts
    for (final pattern in _sqlInjectionPatterns) {
      if (sanitized.toLowerCase().contains(pattern)) {
        return Left(ValidationFailure(
            'Input contains potentially dangerous SQL content.'));
      }
    }

    // Remove or encode special characters if not allowed
    if (!allowSpecialChars) {
      sanitized = sanitized.replaceAll('<', '');
      sanitized = sanitized.replaceAll('>', '');
      sanitized = sanitized.replaceAll('{', '');
      sanitized = sanitized.replaceAll('}', '');
      sanitized = sanitized.replaceAll('\\', '');
      sanitized = sanitized.replaceAll('"', '');
      sanitized = sanitized.replaceAll("'", '');
    } else {
      // HTML encode dangerous characters
      sanitized = _htmlEncode(sanitized);
    }

    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    // Remove null bytes and control characters
    sanitized =
        sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    return Right(sanitized);
  }

  // Sanitize product name
  static Result<String> sanitizeProductName(String name) {
    if (name.trim().isEmpty) {
      return const Left(ValidationFailure('Product name cannot be empty'));
    }

    final result = sanitizeText(name, maxLength: 100, allowSpecialChars: false);

    return result.fold(
      (failure) => Left(failure),
      (sanitized) {
        if (sanitized.length < 2) {
          return const Left(
              ValidationFailure('Product name must be at least 2 characters'));
        }

        // Ensure it doesn't start with numbers or special chars
        if (RegExp(r'^[0-9]').hasMatch(sanitized)) {
          return const Left(
              ValidationFailure('Product name cannot start with a number'));
        }

        return Right(sanitized);
      },
    );
  }

  // Sanitize barcode
  static Result<String> sanitizeBarcode(String barcode) {
    if (barcode.trim().isEmpty) {
      return const Left(ValidationFailure('Barcode cannot be empty'));
    }

    // Remove all non-digit characters
    final sanitized = barcode.replaceAll(RegExp(r'[^\d]'), '');

    if (sanitized.isEmpty) {
      return const Left(ValidationFailure('Barcode must contain digits'));
    }

    if (sanitized.length < 8 || sanitized.length > 14) {
      return const Left(
          ValidationFailure('Barcode must be between 8 and 14 digits'));
    }

    return Right(sanitized);
  }

  // Sanitize price/monetary input
  static Result<double> sanitizePrice(String price) {
    if (price.trim().isEmpty) {
      return const Left(ValidationFailure('Price cannot be empty'));
    }

    // Remove currency symbols and spaces
    String sanitized = price
        .replaceAll(RegExp(r'[\$£€¥₹,\s]'), '')
        .replaceAll(RegExp(r'[^\d\.]'), '');

    // Ensure only one decimal point
    final parts = sanitized.split('.');
    if (parts.length > 2) {
      return const Left(ValidationFailure('Invalid price format'));
    }

    // Limit decimal places to 2
    if (parts.length == 2 && parts[1].length > 2) {
      sanitized = '${parts[0]}.${parts[1].substring(0, 2)}';
    }

    final parsedPrice = double.tryParse(sanitized);
    if (parsedPrice == null) {
      return const Left(ValidationFailure('Invalid price format'));
    }

    if (parsedPrice < 0) {
      return const Left(ValidationFailure('Price cannot be negative'));
    }

    if (parsedPrice > 999999.99) {
      return const Left(ValidationFailure('Price too large'));
    }

    return Right(parsedPrice);
  }

  // Sanitize quantity
  static Result<int> sanitizeQuantity(String quantity) {
    if (quantity.trim().isEmpty) {
      return const Left(ValidationFailure('Quantity cannot be empty'));
    }

    // Remove all non-digit characters
    final sanitized = quantity.replaceAll(RegExp(r'[^\d]'), '');

    if (sanitized.isEmpty) {
      return const Left(ValidationFailure('Quantity must be a number'));
    }

    final parsedQuantity = int.tryParse(sanitized);
    if (parsedQuantity == null) {
      return const Left(ValidationFailure('Invalid quantity format'));
    }

    if (parsedQuantity < 0) {
      return const Left(ValidationFailure('Quantity cannot be negative'));
    }

    if (parsedQuantity > 999999) {
      return const Left(ValidationFailure('Quantity too large'));
    }

    return Right(parsedQuantity);
  }

  // Sanitize category
  static Result<String> sanitizeCategory(String category) {
    if (category.trim().isEmpty) {
      return const Left(ValidationFailure('Category cannot be empty'));
    }

    final result =
        sanitizeText(category, maxLength: 50, allowSpecialChars: false);

    return result.fold(
      (failure) => Left(failure),
      (sanitized) {
        if (sanitized.length < 2) {
          return const Left(
              ValidationFailure('Category must be at least 2 characters'));
        }

        // Capitalize first letter of each word
        final words = sanitized.split(' ');
        final capitalizedWords = words.map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        });

        return Right(capitalizedWords.join(' '));
      },
    );
  }

  // Sanitize search query
  static Result<String> sanitizeSearchQuery(String query) {
    if (query.trim().isEmpty) {
      return const Right('');
    }

    final result =
        sanitizeText(query, maxLength: 200, allowSpecialChars: false);

    return result.fold(
      (failure) => Left(failure),
      (sanitized) {
        // Remove excessive spaces and special search operators that could be dangerous
        String cleaned = sanitized
            .replaceAll(RegExp(r'[^\w\s\-]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        return Right(cleaned);
      },
    );
  }

  // Sanitize email
  static Result<String> sanitizeEmail(String email) {
    if (email.trim().isEmpty) {
      return const Right('');
    }

    final sanitized = email.trim().toLowerCase();

    // Basic email format validation
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(sanitized)) {
      return const Left(ValidationFailure('Invalid email format'));
    }

    // Check for dangerous patterns
    for (final pattern in _dangerousPatterns) {
      if (sanitized.contains(pattern.toLowerCase())) {
        return const Left(
            ValidationFailure('Email contains invalid characters'));
      }
    }

    return Right(sanitized);
  }

  // Sanitize phone number
  static Result<String> sanitizePhoneNumber(String phone) {
    if (phone.trim().isEmpty) {
      return const Right('');
    }

    // Keep only digits, plus, and hyphens
    String sanitized = phone.replaceAll(RegExp(r'[^\d\+\-\(\)\s]'), '');

    // Remove extra spaces
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Basic length validation
    final digitsOnly = sanitized.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return const Left(ValidationFailure('Phone number must be 10-15 digits'));
    }

    return Right(sanitized);
  }

  // Sanitize description/notes
  static Result<String> sanitizeDescription(String description) {
    if (description.trim().isEmpty) {
      return const Right('');
    }

    final result =
        sanitizeText(description, maxLength: 500, allowSpecialChars: true);

    return result.fold(
      (failure) => Left(failure),
      (sanitized) {
        // Allow basic punctuation but remove dangerous content
        String cleaned = sanitized
            .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
            .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
            .trim();

        return Right(cleaned);
      },
    );
  }

  // HTML encode special characters
  static String _htmlEncode(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  // Validate file name for uploads
  static Result<String> sanitizeFileName(String fileName) {
    if (fileName.trim().isEmpty) {
      return const Left(ValidationFailure('File name cannot be empty'));
    }

    // Remove dangerous characters
    String sanitized = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\.\.'), '_')
        .replaceAll(RegExp(r'^\.'), '_')
        .trim();

    // Ensure reasonable length
    if (sanitized.length > 255) {
      sanitized = sanitized.substring(0, 255);
    }

    if (sanitized.isEmpty) {
      return const Left(ValidationFailure('Invalid file name'));
    }

    // Check for dangerous file extensions
    final extension = sanitized.split('.').last.toLowerCase();
    const dangerousExtensions = [
      'exe',
      'bat',
      'cmd',
      'com',
      'pif',
      'scr',
      'vbs',
      'js',
      'jar',
      'php',
      'asp',
      'aspx',
      'jsp',
      'sh',
      'ps1',
      'app',
      'deb',
      'rpm'
    ];

    if (dangerousExtensions.contains(extension)) {
      return const Left(ValidationFailure('File type not allowed'));
    }

    return Right(sanitized);
  }

  // Batch sanitize a map of inputs
  static Result<Map<String, dynamic>> sanitizeInputMap(
    Map<String, dynamic> inputs,
    Map<String, InputSanitizationType> sanitizationRules,
  ) {
    final sanitizedMap = <String, dynamic>{};

    for (final entry in inputs.entries) {
      final key = entry.key;
      final value = entry.value;
      final rule = sanitizationRules[key];

      if (value == null) {
        sanitizedMap[key] = null;
        continue;
      }

      if (rule == null) {
        sanitizedMap[key] = value;
        continue;
      }

      final stringValue = value.toString();
      Result<dynamic> result;

      switch (rule) {
        case InputSanitizationType.text:
          result = sanitizeText(stringValue);
          break;
        case InputSanitizationType.productName:
          result = sanitizeProductName(stringValue);
          break;
        case InputSanitizationType.barcode:
          result = sanitizeBarcode(stringValue);
          break;
        case InputSanitizationType.price:
          result = sanitizePrice(stringValue);
          break;
        case InputSanitizationType.quantity:
          result = sanitizeQuantity(stringValue);
          break;
        case InputSanitizationType.category:
          result = sanitizeCategory(stringValue);
          break;
        case InputSanitizationType.email:
          result = sanitizeEmail(stringValue);
          break;
        case InputSanitizationType.phone:
          result = sanitizePhoneNumber(stringValue);
          break;
        case InputSanitizationType.description:
          result = sanitizeDescription(stringValue);
          break;
        case InputSanitizationType.fileName:
          result = sanitizeFileName(stringValue);
          break;
      }

      final sanitizedResult = result.fold(
        (failure) => throw ValidationException(failure.message),
        (sanitizedValue) => sanitizedValue,
      );

      sanitizedMap[key] = sanitizedResult;
    }

    return Right(sanitizedMap);
  }
}

enum InputSanitizationType {
  text,
  productName,
  barcode,
  price,
  quantity,
  category,
  email,
  phone,
  description,
  fileName,
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}
