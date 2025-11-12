class Benchmark {
  static Future<T> executeAsync<T>(
    String description,
    Future<T> Function() action,
  ) async {
    print(description);

    final stopwatch = Stopwatch()..start();
    final result = await action();
    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    print('Finished in ${_formatDuration(elapsed)}');

    return result;
  }

  static void execute<T>(String description, void Function() action) {
    print(description);

    final stopwatch = Stopwatch()..start();
    final result = action();
    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    print('Finished in ${_formatDuration(elapsed)}');

    return result;
  }

  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds} ms';
    if (d.inSeconds < 60)
      return '${d.inSeconds}.${(d.inMilliseconds % 1000).toString().padLeft(3, '0')} s';
    return '${d.inMinutes} min ${d.inSeconds % 60} s';
  }
}
