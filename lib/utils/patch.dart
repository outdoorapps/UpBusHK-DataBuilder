import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/isar/models/bus_route.dart';
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';

class Patch {
  static final govStopIdToLatLng = {
    // Newly added 竹園村 stop for KMB route 268 and 76
    10000362: LatLng(lat: 22.47576, long: 114.05647),
  };

  static final stopIdToLatLng = {
    '152': LatLng(lat: 22.501070, long: 113.945650),
  };

  static Future<void> patchRoutes() async {
    // "60C1F7910C07C52B" for 115,I,1 KOWLOON CITY FERRY BUS TERMINUS (KC949)
    // need no matching with a CTB stop, KMB included two consecutive
    // terminating stops. This, the last one, is redundant.
    final route115 = await isar.busRoutes
        .filter()
        .numberEqualTo('115')
        .boundEqualTo(Bound.I)
        .serviceTypeEqualTo(1)
        .findFirst();
    if (route115 != null && route115.stops.last == '60C1F7910C07C52B') {
      route115.stops.removeLast();
      await isar.writeTxn(() => isar.busRoutes.put(route115));
    }

    // "F0A8A596641FFC5A" for 170,I SHA TIN STATION BUS TERMINUS (ST941)
    // needs no matching with a CTB stop, KMB included two consecutive
    // terminating stops. This, the last one, is redundant.
    final route170s = await isar.busRoutes
        .filter()
        .numberEqualTo('170')
        .boundEqualTo(Bound.I)
        .findAll();
    route170s.forEach((route170) {
      if (route170.stops.last == 'F0A8A596641FFC5A') {
        route170.stops.removeLast();
      }
    });
    await isar.writeTxn(() => isar.busRoutes.putAll(route170s));
  }

  // todo 107P I 1 use CTB as primary source
  // No match for StopID:69EB1A85EBBBA550, (107P,I,1)
}
