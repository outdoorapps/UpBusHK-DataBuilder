import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';
import 'package:upbushk_data_builder/builders/minibus_route_builder.dart';
import 'package:upbushk_data_builder/builders/minibus_stop_builder.dart';
import 'package:upbushk_data_builder/debug/benchmark.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';
import 'package:upbushk_data_builder/json/minibus_route_info.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

class MinibusBuilder {
  static Future<void> buildMinibusData() async {
    // 1. Build routes and stops using the online API
    final (apiRoutes, apiStops) = await _buildWithApi();

    // 2. Supplement fare for routes and latLng for stops using JSON_GMB.json
    final geoJson = await Benchmark.executeAsync(
      'Parsing JSON_GMB.json',
      _readMinibusData,
    );
    final jsonRoutes = await MinibusRouteBuilder.buildRoutesWithJson(geoJson);

    // Add fare info to json routes
    final routes = <MinibusRoute>[];
    apiRoutes.forEach((e) {
      final jsonRoute = jsonRoutes.firstWhereOrNull(
        (r) => e.routeId == r.routeId,
      );
      jsonRoute == null
          ? routes.add(e)
          : routes.add(e.copyWith(fullFare: jsonRoute.fullFare));
    });
    routes.sort((a, b) => a.routeId.compareTo(b.routeId));

    // Add LatLng to stops
    final jsonStops = MinibusStopBuilder.buildMinibusStopWithJson(geoJson);
    final stops = <MinibusStop>{};
    final pendingStops = <MinibusStop>{};
    apiStops.forEach((e) {
      final stop = jsonStops.firstWhereOrNull((s) => s.stopId == e.stopId);
      stop == null
          ? pendingStops.add(e) // Add api built stop to pending stops
          : stops.add(stop); // Add the json built stop directly
    });

    final results = await MinibusStopBuilder.getLatLngForStops(
      pendingStops.toList(),
    );
    stops.addAll(results);
    final sortedStops = stops.toList()
      ..sort((a, b) => a.stopId.compareTo(b.stopId));

    //todo Save to Isar
    // await isar.writeTxn(() async {
    //   isar.minibusRoutes.putAll(routes);
    //   isar.minibusStops.putAll(sortedStops);
    // });
  }

  /// Use the API to get minibus routes and stops.
  ///
  /// Returns: Tuple of (List<MinibusRoute>, Set<MinibusStop>)
  /// 1. List<MinibusRoute>: List of routes, where each [MinibusRoute.fullFare]
  /// set to null, which is to be obtained from JSON_GMB.json.
  /// 2. Set<MinibusStop>: Set of stops, where each [MinibusStop.latLng] set to
  /// default [LatLng], which is to be obtained from JSON_GMB.json or, if not
  /// available, from the API.
  static Future<(List<MinibusRoute>, Set<MinibusStop>)> _buildWithApi() async {
    // 1. Get routes by region
    final routesByRegion = await Benchmark.executeAsync(
      'Getting minibus routes by region...',
      DataServices.getMinibusRoutesByRegion,
    );

    // 2. Get individual routes
    final minibusRoutes = <MinibusRoute>[];
    final minibusStops = <MinibusStop>{};
    final pendingRegionNumberPairs = routesByRegion.entries
        .expand((e) => e.value.map((number) => MapEntry(e.key, number)))
        .toList();
    int retries = 0;

    while (pendingRegionNumberPairs.isNotEmpty &&
        retries < WebServices.maxRetries) {
      final results = await _apiBuild(pendingRegionNumberPairs);
      final (routes, stops) = results;
      minibusRoutes.addAll(routes);
      minibusStops.addAll(stops);

      // Remove successfully added routes
      routes.forEach(
        (r) => pendingRegionNumberPairs.removeWhere(
          (p) => p.key == r.region && p.value == r.number,
        ),
      );

      final remaining = pendingRegionNumberPairs.length;
      if (remaining > 0) {
        retries++;
        print(
          '$remaining errors received for minibus routes '
          '$pendingRegionNumberPairs, waiting for '
          '${WebServices.timeoutSeconds}s before retrying...',
        );
        await Future.delayed(Duration(seconds: WebServices.timeoutSeconds));
        print('Restarting...');
      }
    }
    return (minibusRoutes, minibusStops);
  }

  /// Return a tuple of (List<MinibusRoute>, Set<MinibusStop>) for the given
  /// [regionNumberPairs].
  static Future<(List<MinibusRoute>, Set<MinibusStop>)> _apiBuild(
    List<MapEntry<Region, String>> regionNumberPairs,
  ) async {
    // Get all routes' info based on region & number (ID, origins, destinations
    // and bound)
    final routesByRegionAndNumber = await Future.wait(
      regionNumberPairs.map(
        (e) => DataServices.getMinibusRoute(e.key.name, e.value),
      ),
    );

    // Separate the routes of the same region & number by bound
    final routesToBound = routesByRegionAndNumber
        .whereType<GovMinibusRoute>()
        .expand((e) => e.directions.map((direction) => MapEntry(e, direction)));

    // Get route stops for each route from the API
    final total = routesToBound.length;
    int completed = 0;
    final lock = Lock();
    final start = DateTime.now();

    final results = await Future.wait(
      routesToBound.map((e) async {
        final govRoute = e.key;
        final direction = e.value;
        final routeStop = await DataServices.getMinibusRouteStops(
          govRoute.routeId,
          direction.routeSeq,
        );

        // Update progress counter atomically
        lock.synchronized(() {
          completed++;
          if (completed % 50 == 0 || completed == total) {
            final percent = (completed / total * 100).toStringAsFixed(1);
            final elapsed = DateTime.now().difference(start).inSeconds;
            stdout.write(
              '\rGetting minibus routes: $completed/$total  $percent%  (${elapsed}s)',
            );
            if (completed == total) stdout.writeln();
          }
        });
        return (govRoute, direction, routeStop);
      }),
    );

    // Build MinibusRoutes and MinibusStops from the results
    final minibusRoutes = <MinibusRoute>[];
    final minibusStops = <MinibusStop>{};

    // todo standardize chi names
    // todo not to include chiS in database, do it runtime on the app
    for (final (govRoute, direction, routeStop) in results) {
      final stops = routeStop.map(
        (stop) => MinibusStop(
          stopId: '${stop.stopId}',
          engName: stop.nameEn,
          chiTName: stop.nameTc,
          chiSName: stop.nameSc,
          latLng: LatLng(),
        ),
      );
      minibusStops.addAll(stops);

      final bound = direction.routeSeq == 1 ? Bound.O : Bound.I;
      final route = MinibusRoute(
        routeId: '${govRoute.routeId}-$bound',
        region: govRoute.region,
        number: govRoute.routeCode,
        bound: bound,
        descriptionEn: govRoute.descriptionEn.trim(),
        descriptionChiT: govRoute.descriptionTc.trim(),
        descriptionChiS: govRoute.descriptionSc.trim(),
        originEn: direction.origEn.trim(),
        originChiT: direction.origTc.trim(),
        originChiS: direction.origSc.trim(),
        destEn: direction.destEn.trim(),
        destChiT: direction.destTc.trim(),
        destChiS: direction.destSc.trim(),
        fullFare: null,
        stops: stops.map((e) => '${e.stopId}').toList(),
      );
      minibusRoutes.add(route);
    }
    return (minibusRoutes, minibusStops);
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
