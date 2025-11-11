class Benchmark {
  static Future<void> executeAsync(
    String description,
    Future<void> Function() action,
  ) async {
    print(description);

    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    print('Finished in ${_formatDuration(elapsed)}');
  }

  static void execute(String description, void Function() action) {
    print(description);

    final stopwatch = Stopwatch()..start();
    action();
    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    print('Finished in ${_formatDuration(elapsed)}');
  }

  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds} ms';
    if (d.inSeconds < 60)
      return '${d.inSeconds}.${(d.inMilliseconds % 1000).toString().padLeft(3, '0')} s';
    return '${d.inMinutes} min ${d.inSeconds % 60} s';
  }
}
