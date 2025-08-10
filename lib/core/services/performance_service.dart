import 'package:firebase_performance/firebase_performance.dart';
import 'package:logger/logger.dart';

class PerformanceService {
  late final FirebasePerformance _performance;
  late final Logger _logger;
  final Map<String, Trace> _activeTraces = {};

  PerformanceService() {
    _performance = FirebasePerformance.instance;
    _logger = Logger();
  }

  // Database Operation Tracing
  Future<T> traceDbOperation<T>(String operation, Future<T> Function() callback) async {
    final trace = _performance.newTrace('db_$operation');
    try {
      await trace.start();
      final result = await callback();
      await trace.stop();
      return result;
    } catch (e) {
      await trace.stop();
      _logger.e('Database operation failed: $operation', error: e);
      rethrow;
    }
  }

  // Screen Loading Performance
  void startScreenTrace(String screenName) {
    final traceName = 'screen_load_$screenName';
    if (_activeTraces.containsKey(traceName)) {
      return; // Already tracking this screen
    }
    
    final trace = _performance.newTrace(traceName);
    _activeTraces[traceName] = trace;
    trace.start();
  }

  void stopScreenTrace(String screenName) {
    final traceName = 'screen_load_$screenName';
    final trace = _activeTraces.remove(traceName);
    if (trace != null) {
      trace.stop();
    }
  }

  // Search Performance
  Future<T> traceSearch<T>(String searchType, Future<T> Function() callback) async {
    final trace = _performance.newTrace('search_$searchType');
    try {
      await trace.start();
      final result = await callback();
      await trace.stop();
      return result;
    } catch (e) {
      await trace.stop();
      _logger.e('Search operation failed: $searchType', error: e);
      rethrow;
    }
  }

  // Barcode Scanning Performance
  void startBarcodeScanTrace() {
    if (_activeTraces.containsKey('barcode_scan')) return;
    
    final trace = _performance.newTrace('barcode_scan');
    _activeTraces['barcode_scan'] = trace;
    trace.start();
  }

  void stopBarcodeScanTrace({bool success = true}) {
    final trace = _activeTraces.remove('barcode_scan');
    if (trace != null) {
      trace.putAttribute('success', success.toString());
      trace.stop();
    }
  }

  // Sale Processing Performance
  Future<T> traceSaleProcessing<T>(Future<T> Function() callback) async {
    final trace = _performance.newTrace('sale_processing');
    try {
      await trace.start();
      final result = await callback();
      await trace.stop();
      return result;
    } catch (e) {
      await trace.stop();
      _logger.e('Sale processing failed', error: e);
      rethrow;
    }
  }

  // Inventory Count Performance
  void startInventoryCountTrace() {
    if (_activeTraces.containsKey('inventory_count')) return;
    
    final trace = _performance.newTrace('inventory_count');
    _activeTraces['inventory_count'] = trace;
    trace.start();
  }

  void stopInventoryCountTrace(int itemsProcessed) {
    final trace = _activeTraces.remove('inventory_count');
    if (trace != null) {
      trace.setMetric('items_processed', itemsProcessed);
      trace.stop();
    }
  }

  // HTTP Request Performance (for future cloud features)
  Future<T> traceHttpRequest<T>(String endpoint, Future<T> Function() callback) async {
    final trace = _performance.newTrace('http_$endpoint');
    try {
      await trace.start();
      final result = await callback();
      await trace.stop();
      return result;
    } catch (e) {
      await trace.stop();
      _logger.e('HTTP request failed: $endpoint', error: e);
      rethrow;
    }
  }

  // Custom Performance Tracing
  void startCustomTrace(String traceName) {
    if (_activeTraces.containsKey(traceName)) return;
    
    final trace = _performance.newTrace(traceName);
    _activeTraces[traceName] = trace;
    trace.start();
  }

  void stopCustomTrace(String traceName, {Map<String, String>? attributes, Map<String, int>? metrics}) {
    final trace = _activeTraces.remove(traceName);
    if (trace != null) {
      if (attributes != null) {
        for (final entry in attributes.entries) {
          trace.putAttribute(entry.key, entry.value);
        }
      }
      
      if (metrics != null) {
        for (final entry in metrics.entries) {
          trace.setMetric(entry.key, entry.value);
        }
      }
      
      trace.stop();
    }
  }

  // Memory Usage Monitoring
  void logMemoryUsage(String context) {
    // This would be implemented with platform-specific code
    // For now, we'll log it for debugging
    _logger.i('Memory usage check: $context');
  }

  // Network Request Performance Monitoring
  HttpMetric createHttpMetric(String url, String method) {
    return _performance.newHttpMetric(url, HttpMethod.values.firstWhere(
      (m) => m.toString().split('.').last.toUpperCase() == method.toUpperCase(),
      orElse: () => HttpMethod.Get,
    ));
  }

  // Cleanup method
  void dispose() {
    for (final trace in _activeTraces.values) {
      try {
        trace.stop();
      } catch (e) {
        _logger.w('Failed to stop trace during cleanup: $e');
      }
    }
    _activeTraces.clear();
  }
}
