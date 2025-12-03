import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_core/isar/models/stop.dart';
import 'package:up_bus_hk_core/isar/models/transit_route.dart';
import 'package:up_bus_hk_data_builder/builders/minibus_route_builder.dart';
import 'package:up_bus_hk_data_builder/builders/minibus_stop_builder.dart';
import 'package:up_bus_hk_data_builder/extension/string_x.dart';
import 'package:up_bus_hk_data_builder/files/project_path.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/json/minibus_geo_json.dart';
import 'package:up_bus_hk_data_builder/json/minibus_route_info.dart';
import 'package:up_bus_hk_data_builder/json/minibus_route_stop.dart';
import 'package:up_bus_hk_data_builder/network/data_services.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';
import 'package:up_bus_hk_data_builder/utils/async_utils.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';

class MinibusBuilder {
  /// Build a list of [MinibusRoute] and [MinibusStop] and save them to Isar
  static Future<void> build({bool clearPreviousData = false}) async {
    if (clearPreviousData) {
      await isar.writeTxn(() async {
        isar.minibusRoutes.clear();
        isar.minibusStops.clear();
      });
    }

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
    // 1. Get routes headers based on region & number
    final routeHeaders = await _getRouteHeaders(regionNumberPairs);

    // 2. Separate the routes headers by bound
    final routeHeaderToBound = routeHeaders
        .whereType<GovMinibusRoute>()
        .expand((e) => e.directions.map((direction) => MapEntry(e, direction)))
        .toList();

    // 3. Get route stops for each route from the API
    final results =
        await AsyncUtils.mapAsyncWithProgress<
          MapEntry<GovMinibusRoute, MinibusDirection>,
          (GovMinibusRoute, MinibusDirection, List<MinibusRouteStop>)
        >(
          items: routeHeaderToBound,
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
        govRouteId: govRoute.routeId,
        region: govRoute.region,
        number: govRoute.routeCode,
        bound: bound,
        descriptionEn: govRoute.descriptionEn.trim(),
        descriptionChiT: govRoute.descriptionTc.trim(),
        originE: direction.origEn.trim(),
        originC: direction.origTc.trim(),
        destE: direction.destEn.trim(),
        destC: direction.destTc.trim(),
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
          nameE: stopWithShortestChiTName.nameEn.trim(),
          nameC: chiTName,
          latLng: LatLng(),
        ),
      );
    });
    minibusStopList.sort((a, b) => a.stopId.compareTo(b.stopId));
    final minibusStops = minibusStopList.toSet();

    print(
      '- Minibus routes: ${minibusRoutes.length}'
      '\n- Minibus stops: ${minibusStops.length}',
    );
    return (minibusRoutes, minibusStops);
  }

  /// Get route headers for the given [regionNumberPairs]. The headers contains
  /// route ID, descriptions and origins & destinations for bounds.
  static Future<List<GovMinibusRoute>> _getRouteHeaders(
    Set<String> regionNumberPairs,
  ) async {
    final routeHeaders =
        await AsyncUtils.mapAsyncWithProgress<String, GovMinibusRoute?>(
          items: regionNumberPairs,
          label: "Getting minibus route headers",
          worker: (key) async {
            final parts = key.split('-');
            final region = parts[0];
            final number = parts[1];

            final response = await WebServices.minibus.getRouteHeader(
              region,
              number,
            );
            return response.routes.firstOrNull;
          },
        );
    return routeHeaders.whereType<GovMinibusRoute>().toList();
  }

  static Future<MinibusGeoJson> _readMinibusData() async {
    final file = File(ProjectPath.minibusDataJson);
    final jsonString = await file.readAsString();
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    return MinibusGeoJson.fromJson(jsonData);
  }
}
