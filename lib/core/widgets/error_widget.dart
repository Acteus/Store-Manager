import 'package:flutter/material.dart';
import '../error/failures.dart';

class AppErrorWidget extends StatelessWidget {
  final Failure failure;
  final VoidCallback? onRetry;
  final String? customMessage;

  const AppErrorWidget({
    Key? key,
    required this.failure,
    this.onRetry,
    this.customMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(),
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _getErrorTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              customMessage ?? _getErrorMessage(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (failure.runtimeType) {
      case NetworkFailure:
        return Icons.wifi_off;
      case DatabaseFailure:
        return Icons.storage;
      case PermissionFailure:
        return Icons.lock;
      case ValidationFailure:
        return Icons.error_outline;
      default:
        return Icons.error_outline;
    }
  }

  String _getErrorTitle() {
    switch (failure.runtimeType) {
      case NetworkFailure:
        return 'Connection Error';
      case DatabaseFailure:
        return 'Data Error';
      case PermissionFailure:
        return 'Permission Required';
      case ValidationFailure:
        return 'Invalid Data';
      default:
        return 'Something went wrong';
    }
  }

  String _getErrorMessage() {
    switch (failure.runtimeType) {
      case NetworkFailure:
        return 'Please check your internet connection and try again.';
      case DatabaseFailure:
        return 'There was a problem accessing your data. Please try again.';
      case PermissionFailure:
        return 'This feature requires additional permissions to work properly.';
      case ValidationFailure:
        return failure.message;
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({Key? key, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppErrorWidget(
      failure: const NetworkFailure('No internet connection'),
      onRetry: onRetry,
    );
  }
}

class DatabaseErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const DatabaseErrorWidget({Key? key, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppErrorWidget(
      failure: const DatabaseFailure('Database error occurred'),
      onRetry: onRetry,
    );
  }
}
