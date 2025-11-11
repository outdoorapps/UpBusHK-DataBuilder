import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/network/data_services.dart';

class MinibusRouteBuilder {
  static Future<List<MinibusRoute>> buildRoutes() async {
    final routesByRegion = await DataServices.getMinibusRoutesByRegion();

    routesByRegion.entries.map((entry) {
      final region = entry.key;
      final routes = entry.value;


    });


    return [];
  }
}