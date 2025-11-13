import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/builders/minibus_route_builder.dart';
import 'package:upbushk_data_builder/builders/minibus_stop_builder.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';

class MinibusBuilder {
  static Future<void> buildMinibusData() async {
    final geoJson = await _readMinibusData();

    // 1. Build routes
    final jsonRoutes = await MinibusRouteBuilder.buildRoutesWithJson(geoJson);
    final (apiRoutes, apiStops) = await MinibusRouteBuilder.buildWithApi();

    final routes = <MinibusRoute>[];

    // Use api routes (online) as references, add fare info from json routes
    apiRoutes.forEach((e) {
      final jsonRoute = jsonRoutes.firstWhereOrNull(
        (r) => e.routeId == r.routeId,
      );
      jsonRoute == null
          ? routes.add(e)
          : routes.add(e.copyWith(fullFare: jsonRoute.fullFare));
    });
    routes.sort((a, b) => a.routeId.compareTo(b.routeId));

    // 2. Build stops
    final stops = await MinibusStopBuilder.buildMinibusStopWithJson(geoJson);

    // Use stops from api routes as references, remove orphan stops
    final apiStopIds = apiRoutes.expand((e) => e.stops).toSet();
    stops.removeWhere((e) => !apiStopIds.contains(e.stopId));

    // Find API stopIds not present in stops
    final stopIds = stops.map((e) => e.stopId).toSet();
    final missingStopIds = apiStopIds.difference(stopIds);

    missingStopIds.forEach((e) => print('Missing stop: $e'));
    // final stopsMissingLatLng = missingStopIds
    //     .map((e) {
    //       final routeStop = geoJson.features.firstWhere(
    //         (f) => f.properties.stopId == e,
    //       );
    //       return MinibusStop(
    //         stopId: e,
    //         engName: routeStop.properties.stopNameE,
    //         chiTName: routeStop.properties.stopNameC,
    //         chiSName: routeStop.properties.stopNameS,
    //         latLng: LatLng(),
    //       );
    //     })
    //     .whereType<MinibusStop>()
    //     .toList();
    // final stopsCreated = await MinibusStopBuilder.getLatLngForStops(
    //   stopsMissingLatLng,
    // );
    // stops.addAll(stopsCreated);
    // stops.sort((a, b) => a.stopId.compareTo(b.stopId));

    //todo Save to Isar
    // await isar.writeTxn(() async {
    //   isar.minibusRoutes.putAll(routes);
    //   isar.minibusStops.putAll(stops);
    // });
  }

  static Future<MinibusGeoJson> _readMinibusData() async {
    final file = File(ProjectPaths.minibusDataJsonPath);
    final jsonString = await file.readAsString();
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    return MinibusGeoJson.fromJson(jsonData);
  }
}

void main() async {
  await MinibusBuilder.buildMinibusData();
}
