import 'dart:async';
import 'dart:io';

import 'package:synchronized/synchronized.dart';

class ProgressTracker {
  final String label;
  final int? total;
  final Lock _lock = Lock();

  int _completed = 0;
  bool _finished = false;
  final DateTime _start = DateTime.now();
  late final Timer _timer;

  ProgressTracker({required this.label, this.total}) {
    // Initial print
    total == null
        ? stdout.write('\r$label...  (0s)')
        : stdout.write('\r$label: 0/$total  0%  (0s)');

    // Print every second until finished
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _lock.synchronized(() {
        final elapsed = DateTime.now().difference(_start).inSeconds;

        if (total == null) {
          stdout.write('\r$label: $_completed  (${elapsed}s)');
        } else if (_completed < total!) {
          // don't overprint final result
          final percent = (_completed / total! * 100).toStringAsFixed(1);
          stdout.write(
            '\r$label: $_completed/$total  $percent%  (${elapsed}s)',
          );
        }
      });
    });
  }

  /// Call this whenever a task finishes
  Future<void> increment() async {
    await _lock.synchronized(() {
      _completed++;

      if (total != null && _completed >= total!) {
        _finished = true;

        // Final print
        final elapsed = DateTime.now().difference(_start).inSeconds;
        final percent = (_completed / total! * 100).toStringAsFixed(1);
        stdout.write(
          '\r$label: $_completed/$total  $percent%  (${elapsed}s)\n',
        );
        _timer.cancel();
      }
    });
  }

  /// This call is only necessary when total was set to null
  void finish() {
    if (_finished) return;
    _finished = true;
    final elapsed = DateTime.now().difference(_start).inSeconds;
    _timer.cancel();
    stdout.write('\r[Completed] $label: $_completed  (${elapsed}s)\n');
  }
}
