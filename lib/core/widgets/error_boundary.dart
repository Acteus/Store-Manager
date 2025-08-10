import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? fallback;
  final void Function(Object error, StackTrace? stackTrace)? onError;
  final String? errorTitle;
  final String? errorMessage;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.fallback,
    this.onError,
    this.errorTitle,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  final Logger _logger = Logger();

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.fallback != null) {
        return widget.fallback!(_error!, _stackTrace);
      }
      return _buildDefaultErrorWidget();
    }
    
    return ErrorCatcher(
      onError: _handleError,
      child: widget.child,
    );
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    _logger.e('Error caught by ErrorBoundary', error: error, stackTrace: stackTrace);
    
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });

    widget.onError?.call(error, stackTrace);
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            widget.errorTitle ?? 'Something went wrong',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.errorMessage ?? 'An unexpected error occurred. Please try again.',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _retry,
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showErrorDetails,
            child: const Text('Show Details'),
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  void _showErrorDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: Text(
            _error.toString() + 
            ((_stackTrace != null) ? '\n\nStack Trace:\n${_stackTrace.toString()}' : ''),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ErrorCatcher extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace? stackTrace) onError;

  const ErrorCatcher({
    Key? key,
    required this.child,
    required this.onError,
  }) : super(key: key);

  @override
  State<ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<ErrorCatcher> {
  @override
  void initState() {
    super.initState();
    
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      widget.onError(details.exception, details.stack);
    };
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Global error handler setup
class GlobalErrorHandler {
  static void initialize() {
    // Catch all uncaught Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger().e(
        'Flutter Error',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    // Catch all uncaught asynchronous errors
    // PlatformDispatcher.instance.onError = (error, stack) {
    //   Logger().e(
    //     'Uncaught Error',
    //     error: error,
    //     stackTrace: stack,
    //   );
    //   return true;
    // };
  }
}

// Retry mechanism widget
class RetryWidget extends StatefulWidget {
  final Future<Widget> Function() builder;
  final Widget Function(Object error)? errorBuilder;
  final Widget? loadingWidget;
  final int maxRetries;
  final Duration retryDelay;

  const RetryWidget({
    Key? key,
    required this.builder,
    this.errorBuilder,
    this.loadingWidget,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<RetryWidget> createState() => _RetryWidgetState();
}

class _RetryWidgetState extends State<RetryWidget> {
  late Future<Widget> _future;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.builder();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ?? 
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error!);
        }

        return snapshot.data ?? const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorWidget(Object error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(error);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        const Text(
          'Something went wrong',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _canRetry() ? _retry : null,
          child: Text(_canRetry() ? 'Retry' : 'Max retries reached'),
        ),
      ],
    );
  }

  bool _canRetry() => _retryCount < widget.maxRetries;

  void _retry() {
    if (!_canRetry()) return;

    setState(() {
      _retryCount++;
      _future = Future.delayed(widget.retryDelay, () => widget.builder());
    });
  }
}

// Resilient future builder with automatic retry
class ResilientFutureBuilder<T> extends StatefulWidget {
  final Future<T> Function() future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final int maxRetries;
  final Duration retryDelay;

  const ResilientFutureBuilder({
    Key? key,
    required this.future,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<ResilientFutureBuilder<T>> createState() => _ResilientFutureBuilderState<T>();
}

class _ResilientFutureBuilderState<T> extends State<ResilientFutureBuilder<T>> {
  late Future<T> _future;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.future();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingBuilder?.call(context) ?? 
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(context, snapshot.error!);
        }

        if (snapshot.hasData) {
          return widget.builder(context, snapshot.data as T);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Failed to load data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Attempt ${_retryCount + 1} of ${widget.maxRetries + 1}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _canRetry() ? _retry : null,
            child: Text(_canRetry() ? 'Retry' : 'Max retries reached'),
          ),
        ],
      ),
    );
  }

  bool _canRetry() => _retryCount < widget.maxRetries;

  void _retry() {
    if (!_canRetry()) return;

    setState(() {
      _retryCount++;
      _future = Future.delayed(widget.retryDelay, () => widget.future());
    });
  }
}
