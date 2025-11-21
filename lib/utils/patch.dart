import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';

class Patch {
  static final govStopIdToLatLng = {
    // Newly added 竹園村 stop for KMB route 268 and 76
    10000362: LatLng(lat: 22.47576, long: 114.05647),
  };

  static final stopIdToLatLng = {
    // Correct NLB Shenzhen Bay station that is off
    '152': LatLng(lat: 22.501070, long: 113.945650),
  };

  static final accountedJointRoute = {
    '8774-1', // Likely an obsolete route
  };

  static Future<void> patchRoutes() async {
    // "60C1F7910C07C52B" for 115,I,1 KOWLOON CITY FERRY BUS TERMINUS (KC949)
    // need no matching with a CTB stop, KMB included two consecutive
    // terminating stops. This, the last one, is redundant.
    final route115s = await builderIsar.companyBusRoutes
        .filter()
        .numberEqualTo('115')
        .boundEqualTo(Bound.I)
        .findAll();
    route115s.forEach((route115) {
      if (route115.stops.last == '60C1F7910C07C52B') {
        route115.stops.removeLast();
      }
    });
    await builderIsar.writeTxn(
      () => builderIsar.companyBusRoutes.putAll(route115s),
    );

    // "F0A8A596641FFC5A" for 170,I SHA TIN STATION BUS TERMINUS (ST941)
    // needs no matching with a CTB stop, KMB included two consecutive
    // terminating stops. This, the last one, is redundant.
    final route170s = await builderIsar.companyBusRoutes
        .filter()
        .numberEqualTo('170')
        .boundEqualTo(Bound.I)
        .findAll();
    route170s.forEach((route170) {
      if (route170.stops.last == 'F0A8A596641FFC5A') {
        route170.stops.removeLast();
      }
    });
    await builderIsar.writeTxn(
      () => builderIsar.companyBusRoutes.putAll(route170s),
    );

    // Merge CTB route 110 outbound with inbound to make a single circular route
    final route110Inbound = await builderIsar.companyBusRoutes
        .filter()
        .numberEqualTo('110')
        .boundEqualTo(Bound.I)
        .companyEqualTo(Company.CTB)
        .findFirst();

    final route110Outbound = await builderIsar.companyBusRoutes
        .filter()
        .numberEqualTo('110')
        .boundEqualTo(Bound.O)
        .companyEqualTo(Company.CTB)
        .findFirst();
    if (route110Inbound != null && route110Outbound != null) {
      final outboundStops = route110Outbound.stops;
      final inboundStops = route110Inbound.stops;
      final startIndex = inboundStops.indexOf(outboundStops.last);
      if (startIndex != -1 && startIndex < inboundStops.length) {
        outboundStops.addAll(
          inboundStops.sublist(startIndex + 1, inboundStops.length),
        );
      }
      await builderIsar.writeTxn(() async {
        builderIsar.companyBusRoutes.delete(route110Inbound.id);
        builderIsar.companyBusRoutes.put(route110Outbound);
      });
    }
  }
}
