import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';
import 'package:upbushk_data_builder/utils/string_x.dart';

class MinibusStopBuilder {
  static List<MinibusStop> buildMinibusStopWithJson(MinibusGeoJson geoJson) {
    final stopIdGroups = groupBy(geoJson.features, (e) => e.properties.stopId);

    return stopIdGroups.entries.map((e) {
      // todo pick the one with the shortest standardized chinese name
      final stop = e.value.first; // Use the first stop in the group

      return MinibusStop(
        stopId: '${e.key}',
        engName: stop.properties.stopNameE.trim(),
        chiTName: stop.properties.stopNameC.standardizeChiStopName(),
        latLng: stop.geometry.latLng,
      );
    }).toList();
  }

  /// Supply the list of [MinibusStop] with coordinates from online api
  static Future<List<MinibusStop>> getLatLngForStops(
    List<MinibusStop> stops,
  ) async {
    final pendingStopIds = stops.map((e) => e.stopId).toSet();
    final stopsWithCoordinate = <MinibusStop>[];
    int retries = 0;

    while (pendingStopIds.isNotEmpty && retries < WebServices.maxRetries) {
      final completed = <String>{};

      await Future.wait(
        pendingStopIds.map((e) async {
          final latLng = await DataServices.getMinibusStopLatLng(int.parse(e));
          if (latLng != null) {
            final pendingStop = stops.firstWhere((s) => s.stopId == e);
            stopsWithCoordinate.add(pendingStop.copyWith(latLng: latLng));
            completed.add(e);
          }
        }),
      );
      pendingStopIds.removeAll(completed);

      final remaining = pendingStopIds.length;
      if (remaining > 0) {
        retries++;
        print(
          '$remaining errors received for minibus stops $pendingStopIds, '
          'waiting for ${WebServices.timeoutSeconds}s before retrying...',
        );
        await Future.delayed(Duration(seconds: WebServices.timeoutSeconds));
        print('Restarting...');
      }
    }
    return stopsWithCoordinate;
  }
}
