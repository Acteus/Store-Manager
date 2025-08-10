import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

class AppReactiveTextField extends StatelessWidget {
  final String formControlName;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final VoidCallback? onTap;
  final bool readOnly;
  final String? helperText;

  const AppReactiveTextField({
    Key? key,
    required this.formControlName,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.onTap,
    this.readOnly = false,
    this.helperText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReactiveTextField(
      formControlName: formControlName,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        errorMaxLines: 2,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      onTap: onTap != null ? (_) => onTap!() : null,
      readOnly: readOnly,
      validationMessages: {
        ValidationMessage.required: (_) => 'This field is required',
        ValidationMessage.email: (_) => 'Please enter a valid email',
        ValidationMessage.minLength: (error) =>
            'Must be at least ${(error as Map)['requiredLength']} characters',
        ValidationMessage.maxLength: (error) =>
            'Must be no more than ${(error as Map)['requiredLength']} characters',
        ValidationMessage.pattern: (_) => 'Invalid format',
      },
    );
  }
}

class AppReactiveDropdown<T> extends StatelessWidget {
  final String formControlName;
  final String? labelText;
  final String? hintText;
  final List<DropdownMenuItem<T>> items;
  final IconData? prefixIcon;

  const AppReactiveDropdown({
    Key? key,
    required this.formControlName,
    required this.items,
    this.labelText,
    this.hintText,
    this.prefixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReactiveDropdownField<T>(
      formControlName: formControlName,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: const OutlineInputBorder(),
      ),
      items: items,
    );
  }
}

class AppReactiveCheckbox extends StatelessWidget {
  final String formControlName;
  final String title;
  final String? subtitle;

  const AppReactiveCheckbox({
    Key? key,
    required this.formControlName,
    required this.title,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReactiveCheckboxListTile(
      formControlName: formControlName,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class AppReactiveSwitch extends StatelessWidget {
  final String formControlName;
  final String title;
  final String? subtitle;

  const AppReactiveSwitch({
    Key? key,
    required this.formControlName,
    required this.title,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReactiveSwitchListTile(
      formControlName: formControlName,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
    );
  }
}

class AppReactiveSlider extends StatelessWidget {
  final String formControlName;
  final String? labelText;
  final double min;
  final double max;
  final int? divisions;

  const AppReactiveSlider({
    Key? key,
    required this.formControlName,
    this.labelText,
    required this.min,
    required this.max,
    this.divisions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
        ReactiveSlider(
          formControlName: formControlName,
          min: min,
          max: max,
          divisions: divisions,
        ),
      ],
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters except decimal point
    String newText = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');

    // Ensure only one decimal point
    final parts = newText.split('.');
    if (parts.length > 2) {
      newText = '${parts[0]}.${parts.sublist(1).join('')}';
    }

    // Limit to 2 decimal places
    if (parts.length == 2 && parts[1].length > 2) {
      newText = '${parts[0]}.${parts[1].substring(0, 2)}';
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class QuantityInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only allow digits
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Remove leading zeros
    if (newText.length > 1 && newText.startsWith('0')) {
      newText = newText.substring(1);
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class BarcodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only allow digits
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 13 characters (EAN-13)
    if (newText.length > 13) {
      newText = newText.substring(0, 13);
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class AppFormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;

  const AppFormSection({
    Key? key,
    required this.title,
    required this.children,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children.map((child) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: child,
            )),
      ],
    );
  }
}

class ReactiveFormErrorDisplay extends StatelessWidget {
  final FormGroup form;

  const ReactiveFormErrorDisplay({
    Key? key,
    required this.form,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReactiveFormConsumer(
      builder: (context, formGroup, child) {
        final errors = _getFormErrors(formGroup);

        if (errors.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Please fix the following errors:',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...errors.map((error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ',
                            style: TextStyle(color: Colors.red.shade600)),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  List<String> _getFormErrors(FormGroup formGroup) {
    final errors = <String>[];

    void collectErrors(AbstractControl control, [String? prefix]) {
      if (control is FormGroup) {
        control.controls.forEach((key, childControl) {
          final fieldPrefix = prefix != null ? '$prefix.$key' : key;
          collectErrors(childControl, fieldPrefix);
        });
      } else if (control.hasErrors) {
        final fieldName = prefix ?? 'Field';
        final errorMessage = control.errors.values.first.toString();
        errors.add('$fieldName: $errorMessage');
      }
    }

    collectErrors(formGroup);
    return errors;
  }
}
