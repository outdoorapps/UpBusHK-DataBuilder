import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:upbushk_data_builder/network/api.dart';

typedef BatchWorker<T> = Future<Set<T>> Function(Set<T> pending);

class WebServices {
  static final Dio _dio = _createDio();

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
          final ts = DateTime.now().toIso8601String();
          print("[Retry][$ts] $obj");
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
    final entries = urlToPath.entries.toList();
    int completed = 0;

    print('Starting ${entries.length} downloads...');

    // process in groups of maxConcurrent
    for (var i = 0; i < entries.length; i += maxConcurrent) {
      final batch = entries.skip(i).take(maxConcurrent).toList();

      // start these downloads in parallel
      await Future.wait(
        batch.map((entry) async {
          await downloadFile(entry.key, entry.value);
          completed++;
          print('✅ [$completed/${urlToPath.length}] ${entry.value}');
        }),
      );
    }

    print('All ${urlToPath.length} downloads completed!');
  }

  static Future<void> downloadFile(String url, String savePath) async {
    final fileName = url.split('/').last;
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );

    final file = File(savePath);
    final sink = file.openWrite();

    final total = response.data?.contentLength ?? 0;
    int received = 0;
    double lastProgress = 0;

    await for (final chunk in response.data!.stream) {
      received += chunk.length;
      sink.add(chunk);

      if (total > 0) {
        final progress = received / total * 100;
        if (progress - lastProgress >= 2) {
          lastProgress = progress;
          stdout.write('\r[$fileName] ${progress.toStringAsFixed(1)}%');
        }
      }
    }

    await sink.close();
    stdout.write('\r[$fileName] 100%');
    print(
      ' Download completed (${(received / 1024 / 1024).toStringAsFixed(1)} MB)',
    );
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
