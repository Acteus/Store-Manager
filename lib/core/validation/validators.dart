import 'package:reactive_forms/reactive_forms.dart';

class AppValidators {
  // Required field validator
  static ValidatorFunction required({String? message}) {
    return (control) {
      if (control.value == null || 
          (control.value is String && (control.value as String).trim().isEmpty)) {
        return {'required': message ?? 'This field is required'};
      }
      return null;
    };
  }

  // Email validator
  static ValidatorFunction email({String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).isEmpty) {
        return null; // Let required validator handle empty values
      }
      
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(control.value as String)) {
        return {'email': message ?? 'Please enter a valid email address'};
      }
      return null;
    };
  }

  // Minimum length validator
  static ValidatorFunction minLength(int length, {String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).isEmpty) {
        return null; // Let required validator handle empty values
      }
      
      if ((control.value as String).length < length) {
        return {
          'minLength': message ?? 'Must be at least $length characters long'
        };
      }
      return null;
    };
  }

  // Maximum length validator
  static ValidatorFunction maxLength(int length, {String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).isEmpty) {
        return null;
      }
      
      if ((control.value as String).length > length) {
        return {
          'maxLength': message ?? 'Must be no more than $length characters long'
        };
      }
      return null;
    };
  }

  // Numeric validator
  static ValidatorFunction numeric({String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).isEmpty) {
        return null;
      }
      
      if (double.tryParse(control.value as String) == null) {
        return {'numeric': message ?? 'Please enter a valid number'};
      }
      return null;
    };
  }

  // Positive number validator
  static ValidatorFunction positiveNumber({String? message}) {
    return (control) {
      if (control.value == null) return null;
      
      double? value;
      if (control.value is String) {
        value = double.tryParse(control.value as String);
      } else if (control.value is num) {
        value = (control.value as num).toDouble();
      }
      
      if (value == null || value <= 0) {
        return {'positiveNumber': message ?? 'Must be a positive number'};
      }
      return null;
    };
  }

  // Minimum value validator
  static ValidatorFunction min(double minimum, {String? message}) {
    return (control) {
      if (control.value == null) return null;
      
      double? value;
      if (control.value is String) {
        value = double.tryParse(control.value as String);
      } else if (control.value is num) {
        value = (control.value as num).toDouble();
      }
      
      if (value == null || value < minimum) {
        return {'min': message ?? 'Must be at least $minimum'};
      }
      return null;
    };
  }

  // Maximum value validator
  static ValidatorFunction max(double maximum, {String? message}) {
    return (control) {
      if (control.value == null) return null;
      
      double? value;
      if (control.value is String) {
        value = double.tryParse(control.value as String);
      } else if (control.value is num) {
        value = (control.value as num).toDouble();
      }
      
      if (value == null || value > maximum) {
        return {'max': message ?? 'Must be no more than $maximum'};
      }
      return null;
    };
  }

  // Integer validator
  static ValidatorFunction integer({String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).isEmpty) {
        return null;
      }
      
      if (int.tryParse(control.value as String) == null) {
        return {'integer': message ?? 'Please enter a whole number'};
      }
      return null;
    };
  }

  // Barcode validator (assuming EAN-13 format)
  static ValidatorFunction barcode({String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).isEmpty) {
        return null;
      }
      
      final barcode = control.value as String;
      
      // Check if it's numeric and has valid length
      if (!RegExp(r'^\d{8,13}$').hasMatch(barcode)) {
        return {
          'barcode': message ?? 'Barcode must be 8-13 digits'
        };
      }
      
      return null;
    };
  }

  // Product name validator
  static ValidatorFunction productName({String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).trim().isEmpty) {
        return null; // Let required validator handle this
      }
      
      final name = (control.value as String).trim();
      
      // Check for minimum length
      if (name.length < 2) {
        return {
          'productName': message ?? 'Product name must be at least 2 characters'
        };
      }
      
      // Check for invalid characters
      if (RegExp(r'[<>{}\\]').hasMatch(name)) {
        return {
          'productName': message ?? 'Product name contains invalid characters'
        };
      }
      
      return null;
    };
  }

  // Category validator
  static ValidatorFunction category({String? message}) {
    return (control) {
      if (control.value == null || (control.value as String).trim().isEmpty) {
        return null;
      }
      
      final category = (control.value as String).trim();
      
      if (category.length < 2) {
        return {
          'category': message ?? 'Category must be at least 2 characters'
        };
      }
      
      return null;
    };
  }

  // Price validator
  static ValidatorFunction price({String? message}) {
    return (control) {
      if (control.value == null) return null;
      
      double? value;
      if (control.value is String) {
        value = double.tryParse(control.value as String);
      } else if (control.value is num) {
        value = (control.value as num).toDouble();
      }
      
      if (value == null) {
        return {'price': message ?? 'Please enter a valid price'};
      }
      
      if (value < 0) {
        return {'price': message ?? 'Price cannot be negative'};
      }
      
      if (value > 999999.99) {
        return {'price': message ?? 'Price is too large'};
      }
      
      // Check for valid decimal places (max 2)
      if (control.value is String) {
        final parts = (control.value as String).split('.');
        if (parts.length > 1 && parts[1].length > 2) {
          return {'price': message ?? 'Price can have at most 2 decimal places'};
        }
      }
      
      return null;
    };
  }

  // Stock quantity validator
  static ValidatorFunction stockQuantity({String? message}) {
    return (control) {
      if (control.value == null) return null;
      
      int? value;
      if (control.value is String) {
        value = int.tryParse(control.value as String);
      } else if (control.value is num) {
        value = (control.value as num).toInt();
      }
      
      if (value == null) {
        return {'stockQuantity': message ?? 'Please enter a valid quantity'};
      }
      
      if (value < 0) {
        return {'stockQuantity': message ?? 'Stock quantity cannot be negative'};
      }
      
      if (value > 999999) {
        return {'stockQuantity': message ?? 'Stock quantity is too large'};
      }
      
      return null;
    };
  }

  // Custom async validator for unique barcode
  static AsyncValidatorFunction uniqueBarcode(
    Future<bool> Function(String barcode) checkUnique, {
    String? message,
  }) {
    return (control) async {
      if (control.value == null || (control.value as String).isEmpty) {
        return null;
      }
      
      final barcode = control.value as String;
      final isUnique = await checkUnique(barcode);
      
      if (!isUnique) {
        return {'uniqueBarcode': message ?? 'This barcode is already in use'};
      }
      
      return null;
    };
  }

  // Composite validator for product form
  static ValidatorFunction productForm() {
    return (control) {
      final formGroup = control as FormGroup;
      
      // Cross-field validation
      final name = formGroup.control('name').value as String?;
      final category = formGroup.control('category').value as String?;
      
      if (name != null && category != null && name.toLowerCase() == category.toLowerCase()) {
        return {
          'productForm': 'Product name and category should be different'
        };
      }
      
      return null;
    };
  }
}

// Helper extension for getting error messages
extension FormControlErrorsExtension on AbstractControl {
  String? get errorMessage {
    if (!hasErrors) return null;
    
    final errors = this.errors;
    
    if (errors.containsKey('required')) {
      return errors['required'] as String;
    }
    if (errors.containsKey('email')) {
      return errors['email'] as String;
    }
    if (errors.containsKey('minLength')) {
      return errors['minLength'] as String;
    }
    if (errors.containsKey('maxLength')) {
      return errors['maxLength'] as String;
    }
    if (errors.containsKey('numeric')) {
      return errors['numeric'] as String;
    }
    if (errors.containsKey('positiveNumber')) {
      return errors['positiveNumber'] as String;
    }
    if (errors.containsKey('min')) {
      return errors['min'] as String;
    }
    if (errors.containsKey('max')) {
      return errors['max'] as String;
    }
    if (errors.containsKey('integer')) {
      return errors['integer'] as String;
    }
    if (errors.containsKey('barcode')) {
      return errors['barcode'] as String;
    }
    if (errors.containsKey('productName')) {
      return errors['productName'] as String;
    }
    if (errors.containsKey('category')) {
      return errors['category'] as String;
    }
    if (errors.containsKey('price')) {
      return errors['price'] as String;
    }
    if (errors.containsKey('stockQuantity')) {
      return errors['stockQuantity'] as String;
    }
    if (errors.containsKey('uniqueBarcode')) {
      return errors['uniqueBarcode'] as String;
    }
    if (errors.containsKey('productForm')) {
      return errors['productForm'] as String;
    }
    
    // Fallback to first error
    return errors.values.first.toString();
  }
}
