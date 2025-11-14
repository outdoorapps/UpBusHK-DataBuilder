import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/json/ctb_route_stop.dart';
import 'package:upbushk_data_builder/json/ctb_stop.dart';
import 'package:upbushk_data_builder/json/kmb_route_stop.dart';
import 'package:upbushk_data_builder/json/minibus_route_stop.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

/// Provide safe calls to APIs that catches exceptions. These should be used
/// when the caller is using [WebServices.retryBatch]. Otherwise, call to the
/// API directly and allow the sequence to crash, thus stopping database
/// creation.
class DataServices {
  static Future<List<KmbRouteStop>> getKmbRouteStops(
    String number,
    String bound,
    String serviceType,
  ) async {
    final response = await WebServices.safeApiCall(
      () => WebServices.kmb.getRouteStops(number, bound, serviceType),
    );
    return response?.stops ?? [];
  }

  static Future<CtbStop?> getCtbStop(String number) async {
    final response = await WebServices.safeApiCall(
      () => WebServices.gov.getCtbStop(number),
    );
    return response?.data;
  }

  static Future<List<CtbRouteStop>> getCtbRouteStops(
    String number,
    String bound,
  ) async {
    final response = await WebServices.safeApiCall(
      () => WebServices.gov.getCtbRouteStops(number, bound),
    );
    return response?.stops ?? [];
  }

  static Future<List<MinibusRouteStop>> getMinibusRouteStops(
    int routeId,
    int routeSeq,
  ) async {
    final response = await WebServices.safeApiCall(
      () => WebServices.minibus.getRouteStops(routeId, routeSeq),
    );
    return response?.data.routeStops ?? [];
  }

  static Future<LatLng?> getMinibusStopLatLng(int stopId) async {
    final response = await WebServices.safeApiCall(
      () => WebServices.minibus.getStop(stopId),
    );
    return response?.data.coordinates.wgs84;
  }
}
