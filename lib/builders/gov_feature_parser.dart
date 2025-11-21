import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:json_events/json_events.dart';
import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';

class GovFeatureParser {
  /// Parses government json/zip file with the following structure and writes
  /// the objects of interest to Isar:
  /// {
  ///    "type": "FeatureCollection",
  ///    "features": [
  ///      objects of interest
  ///    ]
  /// }
  ///
  /// [file] is the json file to be parse
  /// [fromJson] is the function that create object T from json
  /// [writeToIsar] is the function that write T to Isar
  static Future<void> parseData<T>(
    File file, {
    required String label,
    required T? Function(Map<String, dynamic> itemJson) fromJson,
    required Function(List<T>) writeToIsar,
    int batchSize = 10000,
  }) async {
    final inputStream = _openJsonInputStream(file);
    return _parseJsonStream<T>(
      inputStream,
      label: label,
      fromJson: fromJson,
      writeToIsar: writeToIsar,
      batchSize: batchSize,
    );
  }

  /// Returns a stream of bytes for a normal JSON file or a ZIP file.
  ///
  /// If the file extension ends with `.zip`, the first ZIP entry is streamed.
  /// Otherwise, the file is streamed normally.
  static Stream<List<int>> _openJsonInputStream(File file) async* {
    final name = file.path.toLowerCase();

    if (!name.endsWith('.zip')) {
      yield* file.openRead(); // Normal JSON file
      return;
    }

    // ZIP file: decode entire entry into memory, then stream it
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.firstOrNull;
    if (entry == null) {
      throw Exception('Zip file is empty or has no entries: ${file.path}');
    }
    yield* _chunked(entry.content); // entry.content is the decompressed JSON
  }

  static Stream<Uint8List> _chunked(
    Uint8List data, {
    int size = 16 * 1024,
  }) async* {
    for (int i = 0; i < data.length; i += size) {
      final end = (i + size < data.length) ? i + size : data.length;

      yield Uint8List.sublistView(data, i, end);

      // yield to event loop (progress tracker / GC / Isar scheduling)
      await Future.delayed(Duration.zero);
    }
  }

  static Future<void> _parseJsonStream<T>(
    Stream<List<int>> inputStream, {
    required String label,
    required T? Function(Map<String, dynamic>) fromJson,
    required Function(List<T>) writeToIsar,
    int batchSize = 10000,
  }) async {
    final batch = <T>[];
    final writeController = StreamController<List<T>>(sync: true);

    // Write queue
    Future<void> processWriteQueue(Stream<List<T>> stream) async {
      await for (final batch in stream) {
        await writeToIsar(batch);
      }
    }

    final writeFuture = processWriteQueue(writeController.stream);

    // JSON assembly stacks
    final stack = <dynamic>[];
    final keyStack = <String?>[];

    final tracker = ProgressTracker(label: label);

    await inputStream.transform(utf8.decoder).transform(JsonEventDecoder()).flatten().forEach((
      event,
    ) {
      switch (event.type) {
        case JsonEventType.beginObject:
          stack.add(<String, dynamic>{});
          keyStack.add(null);
          break;

        case JsonEventType.beginArray:
          stack.add(<dynamic>[]);
          keyStack.add(null);
          break;

        case JsonEventType.propertyName:
          // propertyName always applies to the top object on the stack
          keyStack[keyStack.length - 1] = event.value as String;
          break;

        case JsonEventType.propertyValue:
          // primitive property values only; for object/array values, value == null
          if (event.value != null) {
            final parent = stack.last;
            if (parent is Map<String, dynamic>) {
              final key = keyStack.last;
              if (key != null) parent[key] = event.value;
            }
          }
          break;

        case JsonEventType.arrayElement:
          // primitive array elements only; complex ones already attached on endObject/endArray
          if (event.value != null) {
            final parent = stack.last;
            if (parent is List) parent.add(event.value);
          }
          break;

        case JsonEventType.endObject:
        case JsonEventType.endArray:
          final completed = stack.removeLast();
          keyStack.removeLast();

          // If this is a Feature object, we handle it *here* and DO NOT keep it in a parent list.
          if (_isFeature(completed)) {
            final feature = completed as Map<String, dynamic>;
            final item = fromJson(feature);
            if (item != null) {
              batch.add(item);
              tracker.increment();
            }

            if (batch.length >= batchSize) {
              writeController.add(List<T>.from(batch));
              batch.clear();
            }
            // Do NOT attach feature back to any parent – this keeps memory small.
            break;
          }

          // Attach the completed object/array to its parent (if any)
          if (stack.isNotEmpty) {
            final parent = stack.last;
            if (parent is List) {
              parent.add(completed);
            } else if (parent is Map<String, dynamic>) {
              final key = keyStack.last;
              if (key != null) parent[key] = completed;
            }
          }
          break;
      }
    });

    if (batch.isNotEmpty) writeController.add(List<T>.from(batch));
    writeController.close();
    await writeFuture;
    tracker.finish();
  }

  static bool _isFeature(dynamic obj) {
    return obj is Map<String, dynamic> &&
        obj['type'] == 'Feature' &&
        obj.containsKey('geometry') &&
        obj.containsKey('properties');
  }
}
