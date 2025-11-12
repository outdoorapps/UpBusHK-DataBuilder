import 'dart:io';

import 'package:flutter_open_chinese_convert/flutter_open_chinese_convert.dart';
import 'package:synchronized/synchronized.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/json/minibus_route_info.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

class MinibusRouteBuilder {
  static Future<List<MinibusRoute>> buildRoutes() async {
    // 1. Get routes by region
    final routesByRegion = await DataServices.getMinibusRoutesByRegion();
    final pendingRegionNumberPairs = routesByRegion.entries
        .expand((e) => e.value.map((number) => MapEntry(e.key, number)))
        .toList();
    final minibusRoutes = <MinibusRoute>[];

    while (pendingRegionNumberPairs.isNotEmpty) {
      final routes = await _getRoutes(pendingRegionNumberPairs);
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
          '$pendingRegionNumberPairs, waiting for'
          ' ${WebServices.timeoutSeconds}s before retrying...',
        );
        await Future.delayed(Duration(seconds: WebServices.timeoutSeconds));
        print('Restarting...');
      }
    }
    return minibusRoutes;
  }

  static Future<List<MinibusRoute>> _getRoutes(
    List<MapEntry<Region, String>> regionNumberPairs,
  ) async {
    // 2. Get route info (ID, origins, destinations and bound)
    final routeInfoList = await Future.wait(
      regionNumberPairs.map(
        (e) => DataServices.getMinibusRouteInfo(e.key, e.value),
      ),
    );

    final routeInfoDirectionPairs = routeInfoList
        .whereType<MinibusRouteInfo>()
        .expand((e) => e.directions.map((direction) => MapEntry(e, direction)));
    final total = routeInfoDirectionPairs.length;
    int completed = 0;
    final lock = Lock();
    final start = DateTime.now();

    return await Future.wait(
      routeInfoDirectionPairs.map((e) async {
        final routeInfo = e.key;
        final direction = e.value;
        final routeSeq = direction.routeSeq;

        final stops = await DataServices.getMinibusRouteStops(
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
              '\rProgress: $completed/$total  $percent%  (${elapsed}s)',
            );
            if (completed == total) stdout.writeln();
          }
        });

        // Create MinibusRoute
        final bound = routeSeq == 1 ? Bound.O : Bound.I; // routeSeq 1 or 2 only

        // Convert simplified Chinese here, as gov data are unreliable
        final descriptionChiT = routeInfo.descriptionTc.trim();
        final descriptionChiS = await ChineseConverter.convert(
          descriptionChiT,
          S2T(),
        );
        final origChiT = direction.origTc.trim();
        final origChiS = await ChineseConverter.convert(origChiT, S2T());
        final destChiT = direction.destTc.trim();
        final destChiS = await ChineseConverter.convert(destChiT, S2T());

        return MinibusRoute(
          govRouteId: routeInfo.routeId,
          region: routeInfo.region,
          number: routeInfo.routeCode,
          bound: bound,
          descriptionEn: routeInfo.descriptionEn.trim(),
          descriptionChiT: descriptionChiT,
          descriptionChiS: descriptionChiS,
          originEn: direction.origEn.trim(),
          originChiT: origChiT,
          originChiS: origChiS,
          destEn: direction.destEn.trim(),
          destChiT: destChiT,
          destChiS: destChiS,
          fullFare: null,
          stops: stops.map((e) => '${e.stopId}').toList(),
        );
      }),
    );
  }
}
