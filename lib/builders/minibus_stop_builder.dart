import 'package:collection/collection.dart';
import 'package:up_bus_hk_core/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/json/minibus_geo_json.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';
import 'package:upbushk_data_builder/utils/async_utils.dart';
import 'package:upbushk_data_builder/extension/string_x.dart';

class MinibusStopBuilder {
  static List<MinibusStop> buildWithJson(MinibusGeoJson geoJson) {
    final stopIdGroups = groupBy(geoJson.features, (e) => e.properties.stopId);

    return stopIdGroups.entries.map((e) {
      // Find the stop with the shortest stop name
      var stopWithShortestChiTName = e.value.first;
      var chiTName = stopWithShortestChiTName.properties.stopNameC
          .standardizeChiStopName();

      for (final stop in e.value.skip(1)) {
        final chi = stop.properties.stopNameC.standardizeChiStopName();

        if (chi.length < chiTName.length) {
          chiTName = chi;
          stopWithShortestChiTName = stop;
        }
      }

      final properties = stopWithShortestChiTName.properties;
      return MinibusStop(
        stopId: '${properties.stopId}',
        engName: properties.stopNameE.trim(),
        chiTName: chiTName,
        latLng: stopWithShortestChiTName.geometry.latLng,
      );
    }).toList();
  }

  /// Supply the list of [MinibusStop] with coordinates from online api
  static Future<List<MinibusStop>> getLatLngForStops(
    List<MinibusStop> stops,
  ) async {
    final pendingStopIds = stops.map((e) => e.stopId).toSet();
    final stopsWithCoordinate = <MinibusStop>[];

    await WebServices.retryBatch<String>(
      pending: pendingStopIds,
      pendingTypeLabel: "minibus stop IDs",
      work: (pendingBatch) async {
        final pendingStops = stops
            .where((s) => pendingBatch.contains(s.stopId))
            .toList();
        final stopsBuilt = await _getLatLngForStopsBatch(pendingStops);
        stopsWithCoordinate.addAll(stopsBuilt);
        return stopsBuilt.map((e) => e.stopId).toSet();
      },
    );
    return stopsWithCoordinate;
  }

  static Future<List<MinibusStop>> _getLatLngForStopsBatch(
    List<MinibusStop> stops,
  ) async {
    final results =
        await AsyncUtils.mapAsyncWithProgress<MinibusStop, MinibusStop?>(
          items: stops,
          label: "Getting minibus stops LatLng",
          worker: (stop) async {
            final latLng = await DataServices.getMinibusStopLatLng(
              int.parse(stop.stopId),
            );
            if (latLng == null) return null;
            return stop.copyWith(latLng: latLng);
          },
        );
    return results.whereType<MinibusStop>().toList();
  }
}
