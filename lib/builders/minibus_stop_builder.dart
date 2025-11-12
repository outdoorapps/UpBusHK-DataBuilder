import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/network/data_services.dart';

class MinibusStopBuilder {
  static Future<List<MinibusStop>> buildMinibusStops(
    List<MinibusRoute> allMinibusRoutes,
  ) async {
    final stopIds = allMinibusRoutes.expand((e) => e.stops).toSet();

    await Future.wait(
      stopIds.map((stopId) async {
        final latLng = await DataServices.getMinibusStopLatLng(int.parse(stopId));
      }),
    );
    return [];
  }
}
