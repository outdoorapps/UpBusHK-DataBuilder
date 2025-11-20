import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:json_events/json_events.dart';
import 'package:up_bus_hk_core/isar/builder_models/bus_fare.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_route_stop.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop_coordinate.dart';
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/json/gov_route_stop_json.dart';
import 'package:up_bus_hk_data_builder/json/gov_stop_coordinate_json.dart';
import 'package:up_bus_hk_data_builder/utils/patch.dart';
import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

class GovBusBuilder {
  static Future<void> build({bool clearPreviousData = false}) async {
    if (clearPreviousData) {
      await builderIsar.writeTxn(() async {
        builderIsar.busFares.clear();
        builderIsar.govRouteStops.clear();
        builderIsar.govStopCoordinates.clear();
        builderIsar.govStops.clear();
        builderIsar.govBusRoutes.clear();
      });
    }

    // 1. Build intermediates
    await _parseRouteStops();
    await _parseStops();
    await _buildBusFareData();

    // 2. Build routes
    final routeHeaders = await builderIsar.govRouteStops
        .where()
        .distinctByRouteId()
        .distinctByRouteSeq()
        .findAll();
    final routes = <GovBusRoute>[];
    final routeTracker = ProgressTracker(label: 'Building gov bus routes');

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
            .sortByOffSeqDesc() // Get the max price for the starting stop
            .distinctByOnSeq()
            .findAll();

        // The last stop has no pairing fare
        final fares = stops.length == busFares.length + 1
            ? busFares.map((f) => f.fare).toList()
            : <double>[];

        final companyCode = e.companyCode == 'LRTFeeder'
            ? 'MTRB'
            : e.companyCode;

        final route = GovBusRoute(
          routeId: e.routeId,
          routeSeq: e.routeSeq,
          companyCode: companyCode,
          number: e.routeName,
          originE: e.locStartNameE,
          originC: e.locStartNameC,
          destE: e.locEndNameE,
          destC: e.locEndNameC,
          serviceMode: e.serviceMode,
          specialType: e.specialType,
          journeyTime: e.journeyTime,
          fullFare: e.fullFare,
          stops: stops.map((s) => s.stopId).toList(),
          fares: fares,
        );
        routes.add(route);
        await routeTracker.increment();
      }),
    );
    routes.sort((a, b) => a.routeId.compareTo(b.routeId));
    await builderIsar.writeTxn(() => builderIsar.govBusRoutes.putAll(routes));
    routeTracker.finish();

    // 3. Build stops
    final stops = <GovStop>[];
    final stopTracker = ProgressTracker(label: 'Building gov bus stops');

    final stopHeaders = await builderIsar.govRouteStops
        .where()
        .distinctByStopId()
        .findAll();

    await Future.wait(
      stopHeaders.map((e) async {
        final govStopCoordinate = await builderIsar.govStopCoordinates
            .where()
            .stopIdEqualTo(e.stopId)
            .findFirst();
        if (govStopCoordinate?.latLng == null &&
            Patch.govStopIdToLatLng[e.stopId] == null) {
          print('[Patching required] Gov stop ${e.stopId} has null latLng');
        }

        final stop = GovStop(
          stopId: e.stopId,
          latLng:
              govStopCoordinate?.latLng ??
              Patch.govStopIdToLatLng[e.stopId] ?? // Try patching it
              LatLng.empty(),
          stopNameE: e.stopNameE,
          stopNameC: e.stopNameC,
        );
        stops.add(stop);
        await stopTracker.increment();
      }),
    );

    stops.sort((a, b) => a.stopId.compareTo(b.stopId));
    await builderIsar.writeTxn(() => builderIsar.govStops.putAll(stops));
    stopTracker.finish();
  }

  static Future<void> _parseRouteStops() async {
    await _parseData<GovRouteStop>(
      File(ProjectPath.busRouteStopJsonPath),
      label: 'Parsing gov bus route-stops',
      fromJson: (itemJson) =>
          GovRouteStopJson.fromJson(itemJson).toGovRouteStop(),
      writeToIsar: (batch) =>
          builderIsar.writeTxn(() => builderIsar.govRouteStops.putAll(batch)),
    );
  }

  static Future<void> _parseStops() async {
    await _parseData<GovStopCoordinate>(
      File(ProjectPath.govStopCoordinatesJsonPath),
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
  static Future<void> _parseData<T>(
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

  static bool _isFeature(dynamic obj) {
    return obj is Map<String, dynamic> &&
        obj['type'] == 'Feature' &&
        obj.containsKey('geometry') &&
        obj.containsKey('properties');
  }

  /// Build bus fare data from FARE_BUS.xml and write to Isar
  static Future<void> _buildBusFareData() async {
    const _batchSize = 10000;

    // Clear existing data
    await builderIsar.writeTxn(() => builderIsar.busFares.clear());

    final file = File(ProjectPath.busFarePath);
    final batch = <BusFare>[];

    // Define the write queue
    final writeController = StreamController<List<BusFare>>(sync: true);
    Future<void> processWriteQueue(Stream<List<BusFare>> stream) async {
      await for (final batch in stream) {
        await builderIsar.writeTxn(() => builderIsar.busFares.putAll(batch));
      }
    }

    final writeFuture = processWriteQueue(writeController.stream);

    final tracker = ProgressTracker(label: 'Parsing bus fare');
    await file
        .openRead()
        .transform(utf8.decoder)
        .toXmlEvents()
        .normalizeEvents()
        .selectSubtreeEvents((event) => event.name == 'FARE')
        .toXmlNodes()
        .expand((nodes) => nodes)
        .forEach((e) {
          final routeId = int.tryParse(
            e.getElement('ROUTE_ID')?.innerText ?? '',
          );
          final routeSeq = int.tryParse(
            e.getElement('ROUTE_SEQ')?.innerText ?? '',
          );
          final onSeq = int.tryParse(e.getElement('ON_SEQ')?.innerText ?? '');
          final offSeq = int.tryParse(e.getElement('OFF_SEQ')?.innerText ?? '');
          final fare = double.tryParse(e.getElement('PRICE')?.innerText ?? '');

          if (routeId != null &&
              routeSeq != null &&
              onSeq != null &&
              offSeq != null &&
              fare != null) {
            final busFare = BusFare(
              routeId: routeId,
              routeSeq: routeSeq,
              onSeq: onSeq,
              offSeq: offSeq,
              fare: fare,
            );
            batch.add(busFare);
            if (batch.length >= _batchSize) {
              writeController.add(List<BusFare>.from(batch));
              batch.clear();
            }
            tracker.increment();
          }
        });

    if (batch.isNotEmpty) writeController.add(List<BusFare>.from(batch));
    writeController.close();
    await writeFuture;
    tracker.finish();
  }
}
