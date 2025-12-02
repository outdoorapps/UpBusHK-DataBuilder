import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_core/isar/models/transit_route.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';

class Patch {
  static final govStopIdToLatLng = {
    // Newly added 竹園村 stop for KMB route 268 and 76
    // Newly added 啟德體育園 stop for SP routes
    10000362: LatLng(lat: 22.47576, long: 114.05647),
    10000309: LatLng(lat: 22.322875, long: 114.193579),
  };

  static final stopIdToLatLng = {
    // Correct NLB Shenzhen Bay station that is off
    '152': LatLng(lat: 22.501070, long: 113.945650),
  };

  static final accountedJointRoute = {
    '8774-1', // Likely an obsolete route
  };

  static final busStopsPatch = {
    BusStop(
      company: Company.KMB,
      stopId: '65E74D034898D16E',
      nameE: 'TO KWA WAN (MOK CHEONG STREET)',
      nameC: '土瓜灣(木廠街)',
      latLng: LatLng(lat: 22.323, long: 114.19007),
    ),
    BusStop(
      company: Company.KMB,
      stopId: '4C61A1E387593CAF',
      nameE: 'DIAMOND HILL (FUNG TAK ROAD)',
      nameC: '鑽石山(鳳德道)',
      latLng: LatLng(lat: 22.34147, long: 114.20274),
    ),
    BusStop(
      company: Company.KMB,
      stopId: 'B3F486EAD0CE8187',
      nameE: 'TAI WAI STATION',
      nameC: '大圍站',
      latLng: LatLng(lat: 22.37395, long: 114.17916),
    ),
    BusStop(
      company: Company.KMB,
      stopId: 'F493236404A4FABF',
      nameE: 'YOHO MALL (YUEN LONG)',
      nameC: '元朗 形點',
      latLng: LatLng(lat: 22.44502, long: 114.03738),
    ),
    BusStop(
      company: Company.KMB,
      stopId: '96E1024FD71C979F',
      nameE: 'THE MILLS',
      nameC: '荃灣南豐紗廠',
      latLng: LatLng(lat: 22.37447, long: 114.11009),
    ),
    BusStop(
      company: Company.KMB,
      stopId: '14736645499B5526',
      nameE: 'STANLEY PLAZA',
      nameC: '赤柱廣場',
      latLng: LatLng(lat: 22.21978, long: 114.20984),
    ),
    BusStop(
      company: Company.KMB,
      stopId: 'DF71339A693A2EA0',
      nameE: 'REPULSE BAY (BEACH ROAD)',
      nameC: '淺水灣(海灘道)',
      latLng: LatLng(lat: 22.23576, long: 114.19824),
    ),
    BusStop(
      company: Company.KMB,
      stopId: '5C6754BD37D3F4D0',
      nameE: 'TUNG CHUNG STATION BUS TERMINUS',
      nameC: '東涌站巴士總站',
      latLng: LatLng(lat: 22.29026, long: 113.94056),
    ),
    BusStop(
      company: Company.KMB,
      stopId: 'A8DC6F85E7043234',
      nameE: 'TSING YI STATION',
      nameC: '青衣站',
      latLng: LatLng(lat: 22.35975, long: 114.10776),
    ),
    BusStop(
      company: Company.CTB,
      stopId: '003888',
      nameE: 'Telford Plaza, Wai Yip Street',
      nameC: '德福廣場, 偉業街',
      latLng: LatLng(lat: 22.3230236, long: 114.2113867),
    ),
    BusStop(
      company: Company.CTB,
      stopId: '003908',
      nameE: 'Telford Plaza, Wai Yip Street',
      nameC: '德福廣場, 偉業街',
      latLng: LatLng(lat: 22.3230087, long: 114.2116055),
    ),
  };

  static Future<void> patchCompanyRoutes() async {
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
      final circularStops = route110Outbound.stops.toList();
      final inboundStops = route110Inbound.stops;
      final startIndex = inboundStops.indexOf(route110Outbound.stops.last);
      if (startIndex != -1 && startIndex < inboundStops.length) {
        circularStops.addAll(
          inboundStops.sublist(startIndex + 1, inboundStops.length),
        );
      }
      final route110Circular = route110Outbound.copyWith(stops: circularStops);
      route110Circular.id = route110Outbound.id;

      await builderIsar.writeTxn(() async {
        builderIsar.companyBusRoutes.delete(route110Inbound.id);
        builderIsar.companyBusRoutes.put(route110Outbound);
      });
    }
  }

  static Future<void> patchBusRoutes() async {
    // 107P use CTB as primary reference
    final route107Ps = await isar.busRoutes
        .filter()
        .numberEqualTo('107P')
        .findAll();
    await Future.forEach(route107Ps, (r) async {
      r.stopFares.forEach((e) {
        final kmbStopId = e.stopId;
        final ctbStopId = e.jointStopId;

        if (ctbStopId != null) {
          e.stopId = ctbStopId;
          e.jointStopId = kmbStopId;
        }
      });
      await isar.writeTxn(() => isar.busRoutes.put(r));
    });
  }

  static Future<void> patchBusStops() async {
    await Future.forEach(Patch.busStopsPatch, (s) async {
      final stop = await isar.busStops
          .where()
          .stopIdEqualTo(s.stopId)
          .findFirst();
      if (stop == null) {
        await isar.writeTxn(() => isar.busStops.put(s));
      } else {
        if (stop.nameE.isEmpty ||
            stop.nameE.isEmpty ||
            !stop.latLng.isValid()) {
          s.id = stop.id;
          await isar.writeTxn(() => isar.busStops.put(s));
        }
      }
    });
  }
}
