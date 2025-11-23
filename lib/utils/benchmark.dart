import 'dart:io';

import 'package:up_bus_hk_data_builder/utils/builder_utils.dart';

class Benchmark {
  static Future<T> executeAsync<T>(
    String description,
    Future<T> Function() action,
  ) async {
    stdout.write('[Running] $description...');

    final stopwatch = Stopwatch()..start();
    final result = await action();
    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    stdout.write(
      '\r[Completed] $description (${BuilderUtils.formatDuration(elapsed)})\n',
    );
    return result;
  }

  static T execute<T>(String description, T Function() action) {
    stdout.write('[Running] $description...');

    final stopwatch = Stopwatch()..start();
    final result = action();
    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    stdout.write(
      '\r[Completed] $description (${BuilderUtils.formatDuration(elapsed)})\n',
    );
    return result;
  }
}
