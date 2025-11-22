import 'package:collection/collection.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/isar/models/transit_route.dart';
import 'package:up_bus_hk_data_builder/json/minibus_geo_json.dart';

class MinibusRouteBuilder {
  /// Use the JSON_GMB.json file to get minibus routes. Routes built by this
  /// function will have [MinibusRoute.fullFare] set and empty descriptions.
  static List<MinibusRoute> buildWithJson(MinibusGeoJson geoJson) {
    final routeToRouteStops = groupBy(
      geoJson.features,
      (e) => MinibusRoute.generateRouteId(
        e.properties.govRouteId,
        Bound.fromMinibusRouteSeq(e.properties.routeSeq),
      ),
    );

    return routeToRouteStops.entries.map((e) {
      final routeStops = e.value;
      routeStops.sort(
        (a, b) => a.properties.stopSeq.compareTo(b.properties.stopSeq),
      );

      // Use the last stop's name as the destination name. The dest texts
      // sometimes is a description and not the real destination.
      final routeInfo = routeStops.last.properties;

      return MinibusRoute(
        govRouteId: routeInfo.govRouteId,
        region: routeInfo.region,
        number: routeInfo.routeNameE,
        bound: Bound.fromMinibusRouteSeq(routeInfo.routeSeq),
        descriptionEn: '',
        descriptionChiT: '',
        originE: routeInfo.locStartNameE.trim(),
        originC: routeInfo.locStartNameC.trim(),
        destE: routeInfo.stopNameE.trim(),
        destC: routeInfo.stopNameC.trim(),
        fullFare: routeInfo.fullFare,
        stops: routeStops.map((e) => '${e.properties.stopId}').toList(),
      );
    }).toList();
  }
}
