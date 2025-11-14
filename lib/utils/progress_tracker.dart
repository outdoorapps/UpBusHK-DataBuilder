import 'dart:io';

import 'package:synchronized/synchronized.dart';

class ProgressTracker {
  final String label; // e.g., "Getting minibus routes"
  final int total;
  final int step; // print every N steps
  final Lock _lock = Lock();

  int _completed = 0;
  final DateTime _start = DateTime.now();

  ProgressTracker({required this.label, required this.total, this.step = 50}) {
    stdout.writeln('\r$label: 0/$total  0%  (0s)'); // Initial print
  }

  Future<void> increment() async {
    await _lock.synchronized(() {
      _completed++;

      if (_completed % step == 0 || _completed == total) {
        final percent = (_completed / total * 100).toStringAsFixed(1);
        final elapsed = DateTime.now().difference(_start).inSeconds;

        stdout.write('\r$label: $_completed/$total  $percent%  (${elapsed}s)');

        if (_completed == total) stdout.writeln();
      }
    });
  }
}
