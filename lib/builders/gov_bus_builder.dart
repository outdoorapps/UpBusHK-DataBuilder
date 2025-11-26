import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/bus_fare.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_route_stop.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop_coordinate.dart';
import 'package:up_bus_hk_core/isar/embedded/gov_stop_fare.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_data_builder/builders/gov_feature_parser.dart';
import 'package:up_bus_hk_data_builder/files/project_path.dart';
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
    final routeTracker = ProgressTracker(label: 'Building gov bus routes');

    final routes = await Future.wait(
      routeHeaders.map((e) async {
        final companyCode = e.companyCode == 'LRTFeeder'
            ? Company.MTRB.name
            : e.companyCode;

        final stops = await builderIsar.govRouteStops
            .where()
            .routeIdRouteSeqEqualTo(e.routeId, e.routeSeq)
            .sortByStopSeq()
            .findAll();

        final busFares = await builderIsar.busFares
            .where()
            .routeIdRouteSeqEqualTo(e.routeId, e.routeSeq)
            .sortByFareDesc() // Get the max fare for the boarding stop
            .distinctByOnSeq()
            .findAll();

        final fares = Map.fromEntries(
          busFares.map((f) => MapEntry(f.onSeq, f.fare)),
        );
        final stopFares = List.generate(stops.length, (i) {
          final onSeq = i + 1;
          return GovStopFare(stopId: stops[i].stopId, fare: fares[onSeq]);
        });

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
          stopFares: stopFares,
        );
        await routeTracker.increment();
        return route;
      }),
    );
    routes.sort((a, b) => a.routeId.compareTo(b.routeId));
    await builderIsar.writeTxn(() => builderIsar.govBusRoutes.putAll(routes));
    routeTracker.finish();

    // 3. Build stops
    final stopTracker = ProgressTracker(label: 'Building gov bus stops');

    final stopHeaders = await builderIsar.govRouteStops
        .where()
        .distinctByStopId()
        .findAll();

    final stops = await Future.wait(
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
              LatLng(),
          stopNameE: e.stopNameE,
          stopNameC: e.stopNameC,
        );
        await stopTracker.increment();
        return stop;
      }),
    );
    stops.sort((a, b) => a.stopId.compareTo(b.stopId));

    await builderIsar.writeTxn(() => builderIsar.govStops.putAll(stops));
    stopTracker.finish();
  }

  static Future<void> _parseRouteStops() async {
    await GovFeatureParser.parseData<GovRouteStop>(
      File(ProjectPath.busRouteStopJson),
      label: 'Parsing gov bus route-stops',
      fromJson: (itemJson) =>
          GovRouteStopJson.fromJson(itemJson).toGovRouteStop(),
      writeToIsar: (batch) =>
          builderIsar.writeTxn(() => builderIsar.govRouteStops.putAll(batch)),
    );
  }

  static Future<void> _parseStops() async {
    await GovFeatureParser.parseData<GovStopCoordinate>(
      File(ProjectPath.busStopsGeoJson),
      label: 'Parsing gov bus stop coordinates',
      fromJson: (itemJson) =>
          GovStopCoordinateJson.fromJson(itemJson).toGovStopCoordinate(),
      writeToIsar: (batch) => builderIsar.writeTxn(
        () => builderIsar.govStopCoordinates.putAll(batch),
      ),
    );
  }

  /// Build bus fare data from FARE_BUS.xml and write to Isar
  static Future<void> _buildBusFareData() async {
    const _batchSize = 10000;

    // Clear existing data
    await builderIsar.writeTxn(() => builderIsar.busFares.clear());

    final file = File(ProjectPath.busFare);
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
