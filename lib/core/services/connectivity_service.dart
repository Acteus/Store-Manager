import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  ConnectivityStatus _status = ConnectivityStatus.unknown;
  StreamSubscription<ConnectivityStatus>? _subscription;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus get status => _status;
  Stream<ConnectivityStatus> get statusStream => _controller.stream;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;

  Future<void> initialize() async {
    // Initial connectivity check
    await checkConnectivity();

    // Start periodic connectivity checks
    _startPeriodicChecks();
  }

  Future<void> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _updateStatus(ConnectivityStatus.online);
      } else {
        _updateStatus(ConnectivityStatus.offline);
      }
    } on SocketException catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    } catch (e) {
      _updateStatus(ConnectivityStatus.unknown);
    }
  }

  void _startPeriodicChecks() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      checkConnectivity();
    });
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _controller.add(_status);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }
}

// Offline-aware mixin for widgets
mixin OfflineAwareMixin<T extends StatefulWidget> on State<T> {
  late StreamSubscription<ConnectivityStatus> _connectivitySubscription;
  ConnectivityStatus _connectivityStatus = ConnectivityStatus.unknown;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription =
        ConnectivityService().statusStream.listen(_onConnectivityChanged);
    _connectivityStatus = ConnectivityService().status;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _onConnectivityChanged(ConnectivityStatus status) {
    if (mounted) {
      setState(() {
        _connectivityStatus = status;
      });
      onConnectivityChanged(status);
    }
  }

  // Override this method in your widgets to handle connectivity changes
  void onConnectivityChanged(ConnectivityStatus status) {}

  bool get isOnline => _connectivityStatus == ConnectivityStatus.online;
  bool get isOffline => _connectivityStatus == ConnectivityStatus.offline;
  ConnectivityStatus get connectivityStatus => _connectivityStatus;
}

// Offline storage service for pending operations
class OfflineStorageService {
  // static const String _pendingOperationsKey = 'pending_operations'; // Reserved for future use
  static final List<PendingOperation> _pendingOperations = [];

  static Future<void> addPendingOperation(PendingOperation operation) async {
    _pendingOperations.add(operation);
    // In a real implementation, you'd persist this to SharedPreferences or SQLite
  }

  static List<PendingOperation> getPendingOperations() {
    return List.from(_pendingOperations);
  }

  static Future<void> removePendingOperation(String id) async {
    _pendingOperations.removeWhere((op) => op.id == id);
    // In a real implementation, you'd update the persisted storage
  }

  static Future<void> clearPendingOperations() async {
    _pendingOperations.clear();
    // In a real implementation, you'd clear the persisted storage
  }

  static int get pendingOperationsCount => _pendingOperations.length;
}

class PendingOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  PendingOperation copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'],
      type: json['type'],
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

// Service to sync pending operations when connectivity is restored
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  final StreamController<bool> _syncStatusController =
      StreamController<bool>.broadcast();

  Stream<bool> get syncStatusStream => _syncStatusController.stream;
  bool get isSyncing => _isSyncing;

  Future<void> syncPendingOperations() async {
    if (_isSyncing || !ConnectivityService().isOnline) {
      return;
    }

    _isSyncing = true;
    _syncStatusController.add(true);

    try {
      final pendingOperations = OfflineStorageService.getPendingOperations();

      for (final operation in pendingOperations) {
        try {
          await _processPendingOperation(operation);
          await OfflineStorageService.removePendingOperation(operation.id);
        } catch (e) {
          // If operation fails, update retry count
          final updatedOperation = operation.copyWith(
            retryCount: operation.retryCount + 1,
          );

          // If max retries exceeded, remove the operation
          if (updatedOperation.retryCount >= 3) {
            await OfflineStorageService.removePendingOperation(operation.id);
          }
        }
      }
    } finally {
      _isSyncing = false;
      _syncStatusController.add(false);
    }
  }

  Future<void> _processPendingOperation(PendingOperation operation) async {
    switch (operation.type) {
      case 'create_product':
        // Process product creation
        break;
      case 'update_product':
        // Process product update
        break;
      case 'delete_product':
        // Process product deletion
        break;
      case 'create_sale':
        // Process sale creation
        break;
      case 'update_inventory':
        // Process inventory update
        break;
      default:
        throw Exception('Unknown operation type: ${operation.type}');
    }
  }

  void dispose() {
    _syncStatusController.close();
  }
}
