import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/builders/minibus_route_builder.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';

class MinibusBuilder {
  static Future<void> buildMinibusData() async {
    final geoJson = await _readMinibusData();

    final routes = await _buildMinibusRoute(geoJson);
    // final stops = await _buildMinibusStop(geoJson);

    // await isar.writeTxn(() async {
    //   isar.minibusRoutes.putAll(routes);
    //   isar.minibusStops.putAll(stops);
    // });

    final onlineRoutes = await MinibusRouteBuilder.buildOnlineRoutes();
    final onlineRouteIds = onlineRoutes.map((e) => e.routeId);
    routes.removeWhere((e) => !onlineRouteIds.contains(e.routeId));

    final routeIDs = routes.map((e) => e.routeId);
    final onlineRoutesToAdd = onlineRouteIds
        .where((e) => !routeIDs.contains(e))
        .map((e) {});

    // todo supplies descriptions
  }

  static Future<MinibusGeoJson> _readMinibusData() async {
    final file = File(ProjectPaths.minibusDataJsonPath);
    final jsonString = await file.readAsString();
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    return MinibusGeoJson.fromJson(jsonData);
  }

  static Future<List<MinibusRoute>> _buildMinibusRoute(
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

        // Convert traditional to simplified Chinese. The json given simplified
        // Chinese is not always accurate.
        final originT = routeInfo.locStartNameC.trim();
        final originS = ''; //Utils.zhT2S.convert(originT);
        final destT = routeInfo.stopNameC.trim();
        final destS = ''; //Utils.zhT2S.convert(destT);

        return MinibusRoute(
          routeId: routeId,
          region: routeInfo.region,
          number: routeInfo.routeNameE,
          bound: routeInfo.bound,
          descriptionEn: '',
          descriptionChiT: '',
          descriptionChiS: '',
          originEn: routeInfo.locStartNameE.trim(),
          originChiT: originT,
          originChiS: originS,
          destEn: routeInfo.stopNameE.trim(),
          destChiT: destT,
          destChiS: destS,
          fullFare: routeInfo.fullFare,
          stops: routeStops.map((e) => '${e.properties.stopId}').toList(),
        );
      }),
    );
  }

  static Future<List<MinibusStop>> _buildMinibusStop(
    MinibusGeoJson geoJson,
  ) async {
    final stopIdGroups = groupBy(geoJson.features, (e) => e.properties.stopId);
    return await Future.wait(
      stopIdGroups.entries.map((e) async {
        final stop = e.value.first;
        final chiTName = stop.properties.stopNameC.trim();
        final chiSName = stop.properties.stopNameS.trim();

        return MinibusStop(
          stopId: '${e.key}',
          engName: stop.properties.stopNameE.trim(),
          chiTName: chiTName,
          chiSName: chiSName,
          coordinate: stop.geometry.coordinates,
        );
      }),
    );
  }
}

void main() async {
  await MinibusBuilder.buildMinibusData();
}
