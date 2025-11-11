import 'package:upbushk_data_builder/json/ctb_route.dart';
import 'package:upbushk_data_builder/json/kmb_route.dart';
import 'package:upbushk_data_builder/json/kmb_route_stop.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

class DataServices {
  static Future<List<KmbRoute>> getKmbRoutes() async {
    final response = await WebServices.safeApiCall(
      () => WebServices.kmb.getRoutes(),
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
}
