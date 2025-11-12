import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_open_chinese_convert/flutter_open_chinese_convert.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';

class MinibusBuilder {
  static Future<void> buildMinibusData() async {
    final geoJson = await _readMinibusData();

    final routeToRouteStops = groupBy(
      geoJson.features,
      (e) => e.properties.routeId,
    );

    routeToRouteStops.entries.map((e) async {
      //todo
      final routeId = e.key;
      final routeStops = e.value;
      routeStops.sort(
        (a, b) => a.properties.stopSeq.compareTo(b.properties.stopSeq),
      );
      final routeInfo = routeStops.first.properties;

      final originT = routeInfo.locStartNameC.trim();
      final originS = await ChineseConverter.convert(originT, S2T());
      final destT = routeInfo.locEndNameC.trim();
      final destS = await ChineseConverter.convert(destT, S2T());

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
        destEn: routeInfo.locEndNameE.trim(), //todo
        destChiT: destT,
        destChiS: destS,
        fullFare: routeInfo.fullFare,
        stops: stops.map((e) => '${e.stopId}').toList(),
      );
    });
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
