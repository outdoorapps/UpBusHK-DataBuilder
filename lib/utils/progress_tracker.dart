import 'dart:async';
import 'dart:io';
import 'package:synchronized/synchronized.dart';

class ProgressTracker {
  final String label;
  final int total;
  final Lock _lock = Lock();

  int _completed = 0;
  final DateTime _start = DateTime.now();
  late final Timer _timer;

  ProgressTracker({required this.label, required this.total}) {
    // Initial print
    stdout.write('\r$label: 0/$total  0%  (0s)');

    // Print every second until finished
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _lock.synchronized(() {
        if (_completed >= total) return; // don't overprint final result

        final percent = (_completed / total * 100).toStringAsFixed(1);
        final elapsed = DateTime.now().difference(_start).inSeconds;

        stdout.write(
          '\r$label: $_completed/$total  $percent%  (${elapsed}s)',
        );
      });
    });
  }

  /// Call this whenever a task finishes
  Future<void> increment() async {
    await _lock.synchronized(() {
      _completed++;
      if (_completed >= total) {
        // Final print
        final percent = (_completed / total * 100).toStringAsFixed(1);
        final elapsed = DateTime.now().difference(_start).inSeconds;
        stdout.write(
          '\r$label: $_completed/$total  $percent%  (${elapsed}s)\n',
        );

        _timer.cancel();
      }
    });
  }
}
