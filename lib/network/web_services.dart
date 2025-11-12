import 'dart:io';

import 'package:dio/dio.dart';
import 'package:upbushk_data_builder/network/api.dart';

class WebServices {
  static const timeoutSeconds = 120;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static final KmbApi kmb = KmbApi(_dio);
  static final GovApi gov = GovApi(_dio);
  static final MinibusApi minibus = MinibusApi(_dio);

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
}
