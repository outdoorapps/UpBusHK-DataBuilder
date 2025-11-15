import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:json_events/json_events.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/gov_route_stop.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/json/gov_route_stop_json.dart';
import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';

class GovBusParser {
  static const _batchSize = 10000;
  final _writeController = StreamController<List<GovRouteStop>>(sync: true);

  Future<void> parseRouteStops() async {
    // Clear existing data
    await isar.writeTxn(() => isar.govRouteStops.clear());

    final file = File(ProjectPaths.busRouteStopJsonPath);
    final batch = <GovRouteStop>[];
    final writeFuture = _processWriteQueue(_writeController.stream);

    // Stack for building nested objects/arrays
    final stack = <dynamic>[]; // List<Map<String,dynamic> or List>
    final keyStack = <String?>[]; // current key for each object level

    final tracker = ProgressTracker(label: 'Parsing gov bus route-stops');
    await file
        .openRead()
        .transform(utf8.decoder)
        .transform(JsonEventDecoder())
        .flatten()
        .forEach((event) {
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
                  if (key != null) {
                    parent[key] = event.value;
                  }
                }
              }
              break;

            case JsonEventType.arrayElement:
              // primitive array elements only; complex ones already attached on endObject/endArray
              if (event.value != null) {
                final parent = stack.last;
                if (parent is List) {
                  parent.add(event.value);
                }
              }
              break;

            case JsonEventType.endObject:
            case JsonEventType.endArray:
              final completed = stack.removeLast();
              keyStack.removeLast();

              // If this is a Feature object, we handle it *here* and DO NOT keep it in a parent list.
              if (_isFeature(completed)) {
                final feature = completed as Map<String, dynamic>;
                final stop = _parseGovRouteStop(feature);
                batch.add(stop);
                tracker.increment();

                if (batch.length >= _batchSize) {
                  _writeController.add(List<GovRouteStop>.from(batch));
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
                  if (key != null) {
                    parent[key] = completed;
                  }
                }
              }
              break;
          }
        });

    if (batch.isNotEmpty) _writeController.add(List<GovRouteStop>.from(batch));
    _writeController.close();
    await writeFuture;
    tracker.finish();
  }

  bool _isFeature(dynamic obj) {
    return obj is Map<String, dynamic> &&
        obj['type'] == 'Feature' &&
        obj.containsKey('geometry') &&
        obj.containsKey('properties');
  }

  GovRouteStop _parseGovRouteStop(Map<String, dynamic> feature) {
    final govRouteStopJson = GovRouteStopJson.fromJson(feature);
    return govRouteStopJson.toGovRouteStop();
  }

  Future<void> _processWriteQueue(Stream<List<GovRouteStop>> stream) async {
    await for (final batch in stream) {
      await isar.writeTxn(() => isar.govRouteStops.putAll(batch));
    }
  }
}
