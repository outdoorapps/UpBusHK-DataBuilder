import 'dart:async';
import 'dart:io';

import 'package:synchronized/synchronized.dart';
import 'package:up_bus_hk_data_builder/utils/builder_utils.dart';

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
        ? stdout.write('\r[Running] $label...  (0s)')
        : stdout.write('\r[Running] $label: 0/$total  0%  (0s)');

    // Print every second until finished
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _lock.synchronized(() {
        final elapsed = DateTime.now().difference(_start);

        if (total == null) {
          final duration = BuilderUtils.formatDuration(elapsed, showMs: false);
          stdout.write('\r[Running] $label: $_completed ($duration)');
        } else if (_completed < total!) {
          // don't overprint final result
          final percent = (_completed / total! * 100).toStringAsFixed(1);
          final duration = BuilderUtils.formatDuration(elapsed, showMs: false);
          stdout.write(
            '\r[Running] $label: $_completed/$total $percent% ($duration)',
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
        finish();
      }
    });
  }

  /// This call is only necessary when total was set to null
  void finish() {
    if (_finished) return;
    _finished = true;
    final elapsed = DateTime.now().difference(_start);
    final duration = BuilderUtils.formatDuration(elapsed);
    _timer.cancel();
    stdout.write('\r[Completed] $label: $_completed ($duration)\n');
  }
}
