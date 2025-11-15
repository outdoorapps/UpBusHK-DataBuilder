import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';

typedef AsyncMapper<I, O> = Future<O> Function(I input);

class AsyncUtils {
  static Future<List<O>> mapAsyncWithProgress<I, O>({
    required Iterable<I> items,
    required String label,
    required AsyncMapper<I, O> worker,
  }) async {
    final tracker = ProgressTracker(label: label, total: items.length);

    return Future.wait(
      items.map((item) async {
        final result = await worker(item);
        await tracker.increment();
        return result;
      }),
    );
  }
}
