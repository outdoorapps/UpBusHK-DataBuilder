import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/builders/minibus_route_builder.dart';
import 'package:upbushk_data_builder/builders/minibus_stop_builder.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/isar_manager.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';
import 'package:upbushk_data_builder/json/minibus_route_info.dart';
import 'package:upbushk_data_builder/json/minibus_route_stop.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';
import 'package:upbushk_data_builder/utils/async_utils.dart';
import 'package:upbushk_data_builder/utils/benchmark.dart';
import 'package:upbushk_data_builder/utils/string_x.dart';

class MinibusBuilder {
  static Future<void> buildMinibusData() async {
    // 1. Build routes and stops using the online API
    final (apiRoutes, apiStops) = await _buildWithApi();

    // 2. Supplement fare for routes and latLng for stops using JSON_GMB.json
    final geoJson = await Benchmark.executeAsync(
      'Parsing JSON_GMB.json',
      _readMinibusData,
    );
    final jsonRoutes = await MinibusRouteBuilder.buildWithJson(geoJson);

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
    final jsonStops = MinibusStopBuilder.buildWithJson(geoJson);
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

    await isar.writeTxn(() async {
      isar.minibusRoutes.putAll(routes);
      isar.minibusStops.putAll(sortedStops);
    });
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
    final response = await Benchmark.executeAsync(
      'Getting minibus routes by region',
      WebServices.minibus.getRoutesByRegion,
    );

    // 2. Get individual routes
    final pendingRegionNumberPairs = response.data.routesByRegion.entries
        .expand((e) => e.value.map((number) => '${e.key.name}-$number'))
        .toSet();

    final minibusRoutes = <MinibusRoute>[];
    final minibusStops = <MinibusStop>{};

    await WebServices.retryBatch<String>(
      pending: pendingRegionNumberPairs,
      pendingTypeLabel: "minibus routes",
      work: (pendingBatch) async {
        final results = await _buildBatch(pendingBatch);
        final (routes, stops) = results;
        minibusRoutes.addAll(routes);
        minibusStops.addAll(stops);

        return routes.map((r) => '${r.region.name}-${r.number}').toSet();
      },
    );
    return (minibusRoutes, minibusStops);
  }

  /// Return a tuple of (List<MinibusRoute>, Set<MinibusStop>) for the given
  /// [regionNumberPairs].
  static Future<(List<MinibusRoute>, Set<MinibusStop>)> _buildBatch(
    Set<String> regionNumberPairs,
  ) async {
    // 1. Get routes overviews based on region & number
    final routeOverviews = await _getRouteOverviews(regionNumberPairs);

    // 2. Separate the routes overviews by bound
    final routeOverviewToBound = routeOverviews
        .whereType<GovMinibusRoute>()
        .expand((e) => e.directions.map((direction) => MapEntry(e, direction)));

    // 3. Get route stops for each route from the API
    final results =
        await AsyncUtils.mapAsyncWithProgress<
          MapEntry<GovMinibusRoute, MinibusDirection>,
          (GovMinibusRoute, MinibusDirection, List<MinibusRouteStop>)
        >(
          items: routeOverviewToBound,
          label: "Building minibus routes",
          worker: (entry) async {
            final govRoute = entry.key;
            final direction = entry.value;

            final routeStops = await DataServices.getMinibusRouteStops(
              govRoute.routeId,
              direction.routeSeq,
            );

            return (govRoute, direction, routeStops);
          },
        );

    // 4. Build routes
    final minibusRoutes = <MinibusRoute>[];

    for (final (govRoute, direction, routeStops) in results) {
      final bound = direction.bound;
      final route = MinibusRoute(
        routeId: '${govRoute.routeId}-$bound',
        region: govRoute.region,
        number: govRoute.routeCode,
        bound: bound,
        descriptionEn: govRoute.descriptionEn.trim(),
        descriptionChiT: govRoute.descriptionTc.trim(),
        originEn: direction.origEn.trim(),
        originChiT: direction.origTc.trim(),
        destEn: direction.destEn.trim(),
        destChiT: direction.destTc.trim(),
        fullFare: null,
        stops: routeStops.map((e) => '${e.stopId}').toList(),
      );
      minibusRoutes.add(route);
    }
    minibusRoutes.sort((a, b) => a.routeId.compareTo(b.routeId));

    // 5. Build stops
    final minibusStopList = <MinibusStop>[];

    final allRouteStops = results.expand((r) => r.$3);
    final stopIdGroups = groupBy(allRouteStops, (e) => e.stopId);
    stopIdGroups.forEach((stopId, routeStops) {
      var stopWithShortestChiTName = routeStops.first;
      var chiTName = stopWithShortestChiTName.nameTc.standardizeChiStopName();

      for (final stop in routeStops.skip(1)) {
        final chi = stop.nameTc.standardizeChiStopName();
        if (chi.length < chiTName.length) {
          chiTName = chi;
          stopWithShortestChiTName = stop;
        }
      }

      minibusStopList.add(
        MinibusStop(
          stopId: '$stopId',
          engName: stopWithShortestChiTName.nameEn.trim(),
          chiTName: chiTName,
          latLng: LatLng(),
        ),
      );
    });
    minibusStopList.sort((a, b) => a.stopId.compareTo(b.stopId));
    final minibusStops = minibusStopList.toSet();

    print(
      'Minibus routes: ${minibusRoutes.length}'
      '\nMinibus stops: ${minibusStops.length}',
    );
    return (minibusRoutes, minibusStops);
  }

  /// Get route overviews for the given [regionNumberPairs]. The overviews
  /// contains route ID, descriptions and origins & destinations for bounds.
  static Future<List<GovMinibusRoute>> _getRouteOverviews(
    Set<String> regionNumberPairs,
  ) async {
    final routeOverviews =
        await AsyncUtils.mapAsyncWithProgress<String, GovMinibusRoute?>(
          items: regionNumberPairs,
          label: "Getting minibus route overviews",
          worker: (key) async {
            final parts = key.split('-');
            final region = parts[0];
            final number = parts[1];

            final response = await WebServices.minibus.getRouteOverview(
              region,
              number,
            );
            return response.routes.firstOrNull;
          },
        );
    return routeOverviews.whereType<GovMinibusRoute>().toList();
  }

  static Future<MinibusGeoJson> _readMinibusData() async {
    final file = File(ProjectPaths.minibusDataJsonPath);
    final jsonString = await file.readAsString();
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    return MinibusGeoJson.fromJson(jsonData);
  }
}
