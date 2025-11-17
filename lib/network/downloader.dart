import 'dart:io';

import 'package:dio/dio.dart';

class Downloader {
  final Dio dio;

  Downloader(this.dio);

  late final List<String> _urls;
  late final List<String> _paths;
  late final List<String> _names;
  late final List<double> _sizesMB;

  Future<void> downloadAll(
    Map<String, String> urlToPath, {
    int maxConcurrent = 5,
  }) async {
    final entries = urlToPath.entries.toList();
    final total = entries.length;

    // Prepare arrays
    _urls = entries.map((e) => e.key).toList(); // remote URLs
    _paths = entries.map((e) => e.value).toList(); // local save paths
    _names = _paths.map(_fileName).toList(); // file names for display
    _sizesMB = List.filled(total, 0.0);

    stdout.writeln('Starting $total downloads...');

    // Process in batches of maxConcurrent
    for (int batchStart = 0; batchStart < total; batchStart += maxConcurrent) {
      final remaining = total - batchStart;
      final batchSize = remaining < maxConcurrent ? remaining : maxConcurrent;
      final batchProgress = List<double>.filled(batchSize, 0.0);

      // Run this batch in parallel
      await Future.wait([
        for (int localIndex = 0; localIndex < batchSize; localIndex++)
          _downloadFile(
            globalIndex: batchStart + localIndex,
            localIndex: localIndex,
            batchStart: batchStart,
            totalFiles: total,
            batchProgress: batchProgress,
          ),
      ]);
      stdout.writeln(); // After the batch is done, move to a new line
    }

    // Final summary
    stdout.writeln('Download completed:');
    for (int i = 0; i < _paths.length; i++) {
      stdout.writeln(
        '${i + 1}. ${_paths[i]} (${_sizesMB[i].toStringAsFixed(1)} MB)',
      );
    }
  }

  Future<void> _downloadFile({
    required int globalIndex,
    required int localIndex,
    required int batchStart,
    required int totalFiles,
    required List<double> batchProgress,
  }) async {
    final url = _urls[globalIndex];
    final savePath = _paths[globalIndex];

    final response = await dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );

    // Make sure directory exists (optional but safer)
    final file = File(savePath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();

    final totalBytes = response.data?.contentLength ?? 0;
    int received = 0;

    await for (final chunk in response.data!.stream) {
      received += chunk.length;
      sink.add(chunk);

      if (totalBytes > 0) {
        batchProgress[localIndex] = received / totalBytes * 100;
        _printBatchProgress(
          batchStart: batchStart,
          totalFiles: totalFiles,
          batchProgress: batchProgress,
        );
      }
    }
    await sink.close();

    _sizesMB[globalIndex] = received / 1024 / 1024;
    batchProgress[localIndex] = 100;
    _printBatchProgress(
      batchStart: batchStart,
      totalFiles: totalFiles,
      batchProgress: batchProgress,
    );
  }

  void _printBatchProgress({
    required int batchStart,
    required int totalFiles,
    required List<double> batchProgress,
  }) {
    final sb = StringBuffer();

    for (int i = 0; i < batchProgress.length; i++) {
      final globalIndex = batchStart + i;
      final pct = batchProgress[i].clamp(0, 100).toStringAsFixed(1);
      sb.write(
        '[${globalIndex + 1}/$totalFiles] ${_names[globalIndex]} ($pct%) ',
      );
    }
    stdout.write('\r${sb.toString()}');
  }

  String _fileName(String path) => path.split('/').last;
}
