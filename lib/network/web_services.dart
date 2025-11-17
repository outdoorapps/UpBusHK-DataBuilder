import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:up_bus_hk_data_builder/network/api.dart';
import 'package:up_bus_hk_data_builder/network/downloader.dart';

typedef BatchWorker<T> = Future<Set<T>> Function(Set<T> pending);

class WebServices {
  static final Dio _dio = _createDio();

  static final _downloader = Downloader(_dio);

  static final KmbApi kmb = KmbApi(_dio);
  static final GovApi gov = GovApi(_dio);
  static final MinibusApi minibus = MinibusApi(_dio);

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        logPrint: (obj) {
          // Only print if it is on the final attempt
          if ('$obj'.contains('attempt: 3/3')) {
            final ts = DateTime.now().toIso8601String();
            print("[Retry][$ts] $obj");
          }
        },
        retries: 3,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 5),
          Duration(seconds: 120),
        ],
      ),
    );
    return dio;
  }

  /// Parallel downloads with maximum of 5 concurrent downloads.
  static Future<void> downloadAll(
    Map<String, String> urlToPath, {
    int maxConcurrent = 5,
  }) async {
    await _downloader.downloadAll(urlToPath, maxConcurrent: maxConcurrent);
  }

  static Future<T?> safeApiCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e, st) {
      print("Dio error: ${e.message}\n$st");
      return null;
    } catch (e, st) {
      print("Unexpected error: $e\n$st");
      return null;
    }
  }

  /// Retries a batch operation until all items succeed or the retry limit is
  /// reached. Logging is printed for remaining items after each failed attempt.
  ///
  /// [pending] contains the items to process.
  /// [pendingTypeLabel] is the label for the pending items, used in error
  /// logging to indicate the type of items remain to be processed.
  /// [work] receives the current pending set and must return the subset that
  /// completed successfully. Those items are removed from [pending].
  /// [maxRetries] limits how many times to retry the operation.
  /// [delaySeconds] is the number of seconds to wait between retries.
  ///
  static Future<void> retryBatch<T>({
    required Set<T> pending,
    required String pendingTypeLabel,
    required BatchWorker<T> work,
    int maxRetries = 3,
    int delaySeconds = 120,
  }) async {
    int retries = 0;

    while (pending.isNotEmpty && retries < maxRetries) {
      final completed = await work(pending);
      pending.removeAll(completed);

      final remaining = pending.length;
      if (remaining > 0) {
        retries++;
        print(
          '$remaining errors remaining for $pendingTypeLabel: $pending, '
          'waiting for ${delaySeconds}s before retrying...',
        );
        await Future.delayed(Duration(seconds: delaySeconds));
        print('Restarting...');
      }
    }
  }
}
