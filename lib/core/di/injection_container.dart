import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import '../../services/database_helper.dart';
import '../../services/barcode_service.dart';
import '../../services/print_service.dart';
import '../../services/notification_service.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/sales_repository.dart';
import '../../repositories/inventory_repository.dart';
import '../services/analytics_service.dart';
import '../services/performance_service.dart';
import '../services/cache_service.dart';
import '../services/error_handler_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core Services
  sl.registerLazySingleton<Logger>(() => Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.none,
        ),
      ));

  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
  sl.registerLazySingleton<BarcodeService>(() => BarcodeService());
  sl.registerLazySingleton<PrintService>(() => PrintService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<CacheService>(() => CacheService());
  sl.registerLazySingleton<ErrorHandlerService>(
      () => ErrorHandlerService(sl()));
  sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  sl.registerLazySingleton<PerformanceService>(() => PerformanceService());

  // Repositories
  sl.registerLazySingleton<ProductRepository>(() => ProductRepositoryImpl(
        databaseHelper: sl(),
        cacheService: sl(),
        logger: sl(),
      ));

  sl.registerLazySingleton<SalesRepository>(() => SalesRepositoryImpl(
        databaseHelper: sl(),
        cacheService: sl(),
        logger: sl(),
      ));

  sl.registerLazySingleton<InventoryRepository>(() => InventoryRepositoryImpl(
        databaseHelper: sl(),
        logger: sl(),
      ));

  // Note: Riverpod providers are registered in the provider files themselves
}
