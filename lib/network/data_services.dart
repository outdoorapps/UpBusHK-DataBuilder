import 'package:upbushk_data_builder/json/ctb_route.dart';
import 'package:upbushk_data_builder/json/ctb_route_stop.dart';
import 'package:upbushk_data_builder/json/kmb_route.dart';
import 'package:upbushk_data_builder/json/kmb_route_stop.dart';
import 'package:upbushk_data_builder/json/kmb_stop.dart';
import 'package:upbushk_data_builder/json/nlb_route.dart';
import 'package:upbushk_data_builder/json/nlb_route_stop.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

class DataServices {
  static Future<List<KmbRoute>> getKmbRoutes() async {
    final response = await WebServices.safeApiCall(
      () => WebServices.kmb.getRoutes(),
    );
    return response?.data ?? [];
  }

  static Future<List<KmbStop>> getKmbStops() async {
    final response = await WebServices.safeApiCall(
      () => WebServices.kmb.getStops(),
    );
    return response?.data ?? [];
  }

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

  static Future<List<CtbRoute>> getCtbRoutes() async {
    final response = await WebServices.safeApiCall(
      () => WebServices.gov.getCtbRoutes(),
    );
    return response?.data ?? [];
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

  static Future<List<NlbRoute>> getNlbRoutes() async {
    final response = await WebServices.safeApiCall(
      () => WebServices.gov.getNlbRoutes(),
    );
    return response?.routes ?? [];
  }

  static Future<List<NlbStop>> getNlbRouteStops(String number) async {
    final response = await WebServices.safeApiCall(
      () => WebServices.gov.getNlbRouteStops(number),
    );
    return response?.stops ?? [];
  }
}
