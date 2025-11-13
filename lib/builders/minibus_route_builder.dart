import 'dart:io';

import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';
import 'package:upbushk_data_builder/json/minibus_route_info.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

class MinibusRouteBuilder {
  /// Use the API to get minibus routes and stops. Routes built by this
  /// will have [MinibusRoute.fullFare] set to null which is to be obtained
  /// via the JSON_GMB.json file. Stops built by this will have
  /// [MinibusStop.latLng] set to default [LatLng], which is to be obtained
  /// from the JSON_GMB.json file or, if not available, from the API.
  static Future<(List<MinibusRoute>, Set<MinibusStop>)> buildWithApi() async {
    // 1. Get routes by region
    final routesByRegion = await DataServices.getMinibusRoutesByRegion();
    final pendingRegionNumberPairs = routesByRegion.entries
        .expand((e) => e.value.map((number) => MapEntry(e.key, number)))
        .toList();
    final minibusRoutes = <MinibusRoute>[];
    final minibusStops = <MinibusStop>{};

    while (pendingRegionNumberPairs.isNotEmpty) {
      final results = await _requestMinibusData(pendingRegionNumberPairs);
      final (routes, stops) = results;
      minibusStops.addAll(stops); // todo should be set and implements ==
      minibusRoutes.addAll(routes);

      // Remove successfully added routes
      routes.forEach(
        (r) => pendingRegionNumberPairs.removeWhere(
          (p) => p.key == r.region && p.value == r.number,
        ),
      );

      final remaining = pendingRegionNumberPairs.length;
      if (remaining > 0) {
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

  static Future<(List<MinibusRoute>, Set<MinibusStop>)> _requestMinibusData(
    List<MapEntry<Region, String>> regionNumberPairs,
  ) async {
    // Get route info (ID, origins, destinations and bound)
    final routeInfoList = await Future.wait(
      regionNumberPairs.map(
        (e) => DataServices.getMinibusRouteInfo(e.key.name, e.value),
      ),
    );

    final routeInfoDirectionPairs = routeInfoList
        .whereType<MinibusRouteInfo>()
        .expand((e) => e.directions.map((direction) => MapEntry(e, direction)));
    final total = routeInfoDirectionPairs.length;
    int completed = 0;
    final lock = Lock();
    final start = DateTime.now();

    final results = await Future.wait(
      routeInfoDirectionPairs.map((e) async {
        final routeInfo = e.key;
        final direction = e.value;
        final routeSeq = direction.routeSeq;

        final routeStop = await DataServices.getMinibusRouteStops(
          routeInfo.routeId,
          routeSeq,
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

        return (routeInfo, direction, routeStop);
      }),
    );

    final minibusRoutes = <MinibusRoute>[];
    final minibusStops = <MinibusStop>{};

    for (final (routeInfo, direction, routeStop) in results) {
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

      // Create MinibusRoute
      final bound = direction.routeSeq == 1 ? Bound.O : Bound.I;

      final route = MinibusRoute(
        routeId: '${routeInfo.routeId}-$bound',
        region: routeInfo.region,
        number: routeInfo.routeCode,
        bound: bound,
        descriptionEn: routeInfo.descriptionEn.trim(),
        descriptionChiT: routeInfo.descriptionTc.trim(),
        descriptionChiS: routeInfo.descriptionSc.trim(),
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

  /// Use the JSON_GMB.json file to get minibus routes. Routes built by this
  /// function will have [MinibusRoute.fullFare] set and empty descriptions.
  static Future<List<MinibusRoute>> buildRoutesWithJson(
    MinibusGeoJson geoJson,
  ) async {
    final routeToRouteStops = groupBy(
      geoJson.features,
      (e) => e.properties.routeId,
    );

    return await Future.wait(
      routeToRouteStops.entries.map((e) async {
        final routeId = e.key;
        final routeStops = e.value;
        routeStops.sort(
          (a, b) => a.properties.stopSeq.compareTo(b.properties.stopSeq),
        );

        // Use the last stop's name as the destination name. The dest texts
        // sometimes is a description and not the real destination.
        final routeInfo = routeStops.last.properties;

        return MinibusRoute(
          routeId: routeId,
          region: routeInfo.region,
          number: routeInfo.routeNameE,
          bound: routeInfo.bound,
          descriptionEn: '',
          descriptionChiT: '',
          descriptionChiS: '',
          originEn: routeInfo.locStartNameE.trim(),
          originChiT: routeInfo.locStartNameC.trim(),
          originChiS: routeInfo.locStartNameS.trim(),
          destEn: routeInfo.stopNameE.trim(),
          destChiT: routeInfo.stopNameC.trim(),
          destChiS: routeInfo.stopNameS.trim(),
          fullFare: routeInfo.fullFare,
          stops: routeStops.map((e) => '${e.properties.stopId}').toList(),
        );
      }),
    );
  }
}
