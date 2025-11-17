import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop.dart';
import 'package:up_bus_hk_core/isar/models/bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_data_builder/extension/lat_lng_x.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/utils/builder_utils.dart';

class BusRouteBuilder {
  static const double _routeInfoErrorDistanceMeters = 220.0; // 38X cap
  static const double _jointRouteMatchingRadiusMeters = 160.0;
  static const double _circularRouteMatchingRadiusMeters = 250.0; // CTB 25 cap
  static const double _stopPairingRadiusMeters = 50.0;

  static late final Map<int, GovStop> govStopMap;
  static late final Map<String, BusStop> busStopMap;

  // todo patch mapping "152" to 12728

  static Future<List<BusRoute>> build() async {
    // await GovBusBuilder.build(clearPreviousData: true); //todo
    final routes = <BusRoute>[];

    final govStops = await builderIsar.govStops.where().findAll();
    govStopMap = Map.fromEntries(govStops.map((e) => MapEntry(e.stopId, e)));

    final busStops = await isar.busStops.where().findAll();
    busStopMap = Map.fromEntries(busStops.map((e) => MapEntry(e.stopId, e)));

    final kmbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.KMB)
        .findAll();

    final ctbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.CTB)
        .findAll();

    int count = 0;
    for (final route in kmbCompanyRoutes) {
      final govRoute = await _matchGovRoute(route);
      if (govRoute != null) count++;

      // BusRoute(
      //   routeId: '',
      //   //todo generate
      //   companies: [isLwb ? Company.LWB : Company.KMB],
      //   number: e.number,
      //   bound: e.bound,
      //   secondaryBound: null,
      //   originE: e.originEn,
      //   originC: e.originChiT,
      //   destE: e.destEn,
      //   destC: e.destChiT,
      //   fullFare: null,
      //   stops: e.stops,
      //   secondaryStops: [],
      //   fares: [],
      //   serviceType: null,
      //   nlbRouteId: null,
      //   trackId: null,
      // );
    }
    print('count (gov routes): $count/${builderIsar.govBusRoutes.countSync()}');
    print('count: $count/${kmbCompanyRoutes.length}');

    return [];
  }

  static Future<GovBusRoute?> _matchGovRoute(CompanyBusRoute route) async {
    // 1. Filter by company & number
    final isKmb = route.company == Company.KMB;
    final potentials = await builderIsar.govBusRoutes
        .where()
        .numberEqualTo(route.number)
        .filter()
        .group(
          (q) => isKmb
              ? q.companyCodeContains('KMB').or().companyCodeContains('LWB')
              : q.companyCodeContains(route.company.name),
        )
        .findAll();
    print('potentials: ${potentials.length}');
    if (potentials.isEmpty) return null;

    // 2. Match bound
    final boundMatched = potentials.where((e) => _isBoundMatch(route, e));
    return switch (boundMatched.length) {
      0 => null,
      1 => boundMatched.first,
      // 3. If more than one candidates, return the one with the most pairing
      // stops (this has been the most accurate matching method)
      _ => _getGovRouteWithMostPairingStops(route, boundMatched.toList()),
    };
  }

  static bool _isBoundMatch(CompanyBusRoute route, GovBusRoute govRoute) {
    final origin = busStopMap[route.stops.first]!;
    final govOrigin = govStopMap[govRoute.stops.first]!;
    final dest = busStopMap[route.stops.last]!;
    final govDest = govStopMap[govRoute.stops.last]!;

    // I. Check if the origins are the same
    final originDistance = BuilderUtils.distance(
      origin.latLng.toLatLong(),
      govOrigin.latLng.toLatLong(),
    );
    if (originDistance > _jointRouteMatchingRadiusMeters) return false;

    // II. Check if the destinations are the same
    final destDistance = BuilderUtils.distance(
      dest.latLng.toLatLong(),
      govDest.latLng.toLatLong(),
    );
    if (destDistance > _jointRouteMatchingRadiusMeters) return false;

    // III. For a circular route, gov route omits the last stop. Check if the
    // company route destination is the same as the gov route origin.
    if (govRoute.originE == govRoute.destE) {
      final terminalDistance = BuilderUtils.distance(
        govOrigin.latLng.toLatLong(),
        dest.latLng.toLatLong(),
      );
      if (terminalDistance <= _circularRouteMatchingRadiusMeters) return true;
    }
    return true;
  }

  static GovBusRoute _getGovRouteWithMostPairingStops(
    CompanyBusRoute route,
    List<GovBusRoute> govRoutes,
  ) {
    final govRouteToPairStopCount = govRoutes.map(
      (e) => MapEntry(e, _countMatchingStops(route, e)),
    );
    return govRouteToPairStopCount
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  static int _countMatchingStops(CompanyBusRoute route, GovBusRoute govRoute) {
    int count = 0;
    final govStops = govRoute.stops.toList();

    route.stops.forEach((s) {
      final busStop = busStopMap[s]!;
      final latLong = busStop.latLng.toLatLong();

      final distances = govStops.map((e) {
        final govStop = govStopMap[e]!;
        return MapEntry(
          e,
          BuilderUtils.distance(latLong, govStop.latLng.toLatLong()),
        );
      });
      final minDistance = distances.reduce((a, b) => a.value < b.value ? a : b);
      if (minDistance.value <= _stopPairingRadiusMeters) {
        count++;
        govStops.remove(minDistance.key);
      }
    });
    return count;
  }
}
