import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../error/failures.dart';

class ErrorHandlerService {
  final Logger _logger;

  ErrorHandlerService(this._logger);

  void logError(dynamic error, [StackTrace? stackTrace]) {
    _logger.e('Error occurred', error: error, stackTrace: stackTrace);
  }

  void logWarning(String message) {
    _logger.w(message);
  }

  void logInfo(String message) {
    _logger.i(message);
  }

  String getErrorMessage(Failure failure) {
    switch (failure.runtimeType) {
      case DatabaseFailure:
        return _getDatabaseErrorMessage(failure as DatabaseFailure);
      case NetworkFailure:
        return _getNetworkErrorMessage(failure as NetworkFailure);
      case ValidationFailure:
        return _getValidationErrorMessage(failure as ValidationFailure);
      case PermissionFailure:
        return _getPermissionErrorMessage(failure as PermissionFailure);
      case CacheFailure:
        return _getCacheErrorMessage(failure as CacheFailure);
      default:
        return _getGenericErrorMessage(failure);
    }
  }

  String _getDatabaseErrorMessage(DatabaseFailure failure) {
    switch (failure.code) {
      case 'SQLITE_CONSTRAINT_UNIQUE':
        return 'This item already exists. Please check your data.';
      case 'SQLITE_CONSTRAINT_FOREIGNKEY':
        return 'Cannot perform this action due to data dependencies.';
      case 'SQLITE_READONLY':
        return 'Database is read-only. Please check app permissions.';
      default:
        return 'Database error occurred. Please try again.';
    }
  }

  String _getNetworkErrorMessage(NetworkFailure failure) {
    switch (failure.code) {
      case 'NO_INTERNET':
        return 'No internet connection. Please check your network.';
      case 'TIMEOUT':
        return 'Request timed out. Please try again.';
      case 'SERVER_ERROR':
        return 'Server error occurred. Please try again later.';
      default:
        return 'Network error occurred. Please check your connection.';
    }
  }

  String _getValidationErrorMessage(ValidationFailure failure) {
    return failure.message;
  }

  String _getPermissionErrorMessage(PermissionFailure failure) {
    switch (failure.code) {
      case 'CAMERA_DENIED':
        return 'Camera permission is required for barcode scanning.';
      case 'STORAGE_DENIED':
        return 'Storage permission is required for this feature.';
      default:
        return 'Permission required for this feature.';
    }
  }

  String _getCacheErrorMessage(CacheFailure failure) {
    return 'Data caching error. App may run slower than usual.';
  }

  String _getGenericErrorMessage(Failure failure) {
    return failure.message.isNotEmpty 
        ? failure.message 
        : 'An unexpected error occurred. Please try again.';
  }

  void showErrorSnackBar(BuildContext context, Failure failure) {
    final message = getErrorMessage(failure);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> showErrorDialog(BuildContext context, Failure failure) async {
    final message = getErrorMessage(failure);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
