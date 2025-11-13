import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

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
          latLng: stop.geometry.latLng,
        );
      }),
    );
  }

  /// Supply the list of [MinibusStop] with coordinates from online api
  static Future<List<MinibusStop>> getLatLngForStops(
    List<MinibusStop> stops,
  ) async {
    final pendingStopIds = stops.map((e) => e.stopId).toSet();
    final stopsWithCoordinate = <MinibusStop>[];

    while (pendingStopIds.isNotEmpty) {
      await Future.wait(
        pendingStopIds.map((e) async {
          final coordinate = await DataServices.getMinibusStopLatLng(
            int.parse(e),
          );
          if (coordinate != null) {
            final pendingStop = stops.firstWhere((s) => s.stopId == e);
            stopsWithCoordinate.add(pendingStop.copyWith(latLng: coordinate));
          }
        }),
      );
      pendingStopIds.removeAll(stopsWithCoordinate.map((e) => e.stopId));

      final remaining = pendingStopIds.length;
      if (remaining > 0) {
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
