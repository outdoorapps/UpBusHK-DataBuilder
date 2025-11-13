import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';

class MinibusStopBuilder {
  static Future<List<MinibusStop>> buildMinibusStopWithJson(
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
