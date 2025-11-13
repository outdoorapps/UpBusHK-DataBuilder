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
    final apiRoutes = await MinibusRouteBuilder.buildRoutesWithApi();
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

    // Find stops missing LatLng (not present in GMB_stops.json)
    final stopWithoutLatLng = stops.where((e) => e.latLng == null)
        .map((e) => stops.firstWhere((s) => s.stopId == e))
        .toList();
    final stopsWithApiLatLng = await MinibusStopBuilder.getLatLngForStops(
      stopWithoutLatLng,
    );
    stopWithoutLatLng.forEach((e) => stops.remove(e));

    stops.addAll(stopsWithApiLatLng);

    stops.sort((a, b) => a.stopId.compareTo(b.stopId));

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
