import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:json_events/json_events.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/bus_fare.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/gov_route_stop.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/gov_stop_coordinate.dart';
import 'package:up_bus_hk_data_builder/builders/bus_fare_parser.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/json/gov_route_stop_json.dart';
import 'package:up_bus_hk_data_builder/json/gov_stop_coordinate_json.dart';
import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';

class GovBusBuilder {
  Future<void> build() async {
    await parseRouteStops();
    await parseStops();
    await BusFareParser().parseBusFareData();

    final routeHeaders = await builderIsar.govRouteStops
        .where()
        .distinctByRouteId()
        .distinctByRouteSeq()
        .findAll();
    final routes = <GovBusRoute>[];
    final tracker = ProgressTracker(label: 'Building gov bus routes');

    await Future.wait(
      routeHeaders.map((e) async {
        final stops = await builderIsar.govRouteStops
            .where()
            .routeIdRouteSeqEqualTo(e.routeId, e.routeSeq)
            .sortByRouteSeq()
            .findAll();

        final busFares = await builderIsar.busFares
            .where()
            .routeIdRouteSeqEqualTo(e.routeId, e.routeSeq)
            .sortByOnSeq()
            .findAll();
        final fares = stops.length == busFares.length
            ? busFares.map((f) => f.fare).toList()
            : <double>[];

        final route = GovBusRoute(
          routeId: e.routeId,
          routeSeq: e.routeSeq,
          companyCode: e.companyCode,
          routeNameE: e.routeName,
          originEn: e.locStartNameE,
          originChiT: e.locStartNameC,
          destEn: e.locEndNameE,
          destChiT: e.locEndNameC,
          serviceMode: e.serviceMode,
          specialType: e.specialType,
          journeyTime: e.journeyTime,
          fullFare: e.fullFare,
          stops: stops.map((s) => s.stopId).toList(),
          fares: fares,
        );
        routes.add(route);
        tracker.increment();
      }),
      //todo stops
    );
    routes.sort((a, b) => a.routeId.compareTo(b.routeId));

    await builderIsar.writeTxn(() => builderIsar.govBusRoutes.putAll(routes));
    tracker.finish();

    // print('${routeHeaders.length}');

    // routeHeaders.forEach((routeHeader) {
    //   final companyCode = routeHeader.companyCode;
    //   if (companyCode != 'CTB' &&
    //       companyCode != 'KMB' &&
    //       companyCode != 'NLB' &&
    //       companyCode != 'LWB' &&
    //       !companyCode.contains('+')) {
    //     print(
    //       '${routeHeader.routeName}-${routeHeader.routeSeq}, ${routeHeader.companyCode}',
    //     );
    //   }
    // });
  }

  Future<void> parseRouteStops() async {
    // Clear existing data
    await builderIsar.writeTxn(() => builderIsar.govRouteStops.clear());

    await _parseData<GovRouteStop>(
      File(ProjectPaths.busRouteStopJsonPath),
      label: 'Parsing gov bus route-stops',
      fromJson: (itemJson) =>
          GovRouteStopJson.fromJson(itemJson).toGovRouteStop(),
      writeToIsar: (batch) =>
          builderIsar.writeTxn(() => builderIsar.govRouteStops.putAll(batch)),
    );
  }

  Future<void> parseStops() async {
    // Clear existing data
    await builderIsar.writeTxn(() => builderIsar.govStopCoordinates.clear());

    await _parseData<GovStopCoordinate>(
      File(ProjectPaths.govStopCoordinatesJsonPath),
      label: 'Parsing gov bus stop coordinates',
      fromJson: (itemJson) =>
          GovStopCoordinateJson.fromJson(itemJson).toGovStopCoordinate(),
      writeToIsar: (batch) => builderIsar.writeTxn(
        () => builderIsar.govStopCoordinates.putAll(batch),
      ),
    );
  }

  /// Parses government json file with the following structure and writes the
  /// objects of interest to Isar:
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
  Future<void> _parseData<T>(
    File file, {
    required String label,
    required T Function(Map<String, dynamic> itemJson) fromJson,
    required Function(List<T>) writeToIsar,
  }) async {
    const batchSize = 10000;
    final batch = <T>[];
    final writeController = StreamController<List<T>>(sync: true);

    // Define the write queue
    Future<void> processWriteQueue(Stream<List<T>> stream) async {
      await for (final batch in stream) {
        await writeToIsar(batch);
      }
    }

    final writeFuture = processWriteQueue(writeController.stream);

    // Stack for building nested objects/arrays
    final stack = <dynamic>[]; // List<Map<String,dynamic> or List>
    final keyStack = <String?>[]; // current key for each object level

    final tracker = ProgressTracker(label: label);
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
                batch.add(item);
                tracker.increment();

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

  bool _isFeature(dynamic obj) {
    return obj is Map<String, dynamic> &&
        obj['type'] == 'Feature' &&
        obj.containsKey('geometry') &&
        obj.containsKey('properties');
  }
}
