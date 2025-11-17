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
  static const double _jointRouteErrorDistanceMeters = 160.0;
  static const double _circularRouteErrorDistanceMeters = 250.0; // CTB 25 cap
  static const double _stopMatchErrorDistanceMeters = 50.0;

  static late final Map<int, GovStop> govStopMap;
  static late final Map<String, BusStop> busStopMap;

  static Future<List<BusRoute>> build() async {
    // await GovBusBuilder.build(); //todo
    final routes = <BusRoute>[];

    final govStops = await builderIsar.govStops.where().findAll();
    govStopMap = Map.fromEntries(govStops.map((e) => MapEntry(e.stopId, e)));

    final busStops = await builderIsar.busStops.where().findAll();
    busStopMap = Map.fromEntries(busStops.map((e) => MapEntry(e.stopId, e)));

    final kmbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.KMB)
        .findAll();

    final ctbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.CTB)
        .findAll();

    for (final route in kmbCompanyRoutes) {
      final govRoute = await _matchGovRoute(route);

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
              ? q.companyCodeContains('KMB').companyCodeContains('LWB')
              : q.companyCodeContains(route.company.name),
        )
        .findAll();

    // 2. Match bound
    final boundMatched = potentials.where((e) => _isBoundMatch(route, e));
    //todo try matching reversed
    //todo circular route

    // 3. Match stops
    final matched = boundMatched.where((e) => _areStopsMatch(route, e));

    return matched.isNotEmpty ? matched.first : null;
  }

  static bool _isBoundMatch(CompanyBusRoute route, GovBusRoute govRoute) {
    final origin = busStopMap[route.stops.first]!;
    final govOrigin = govStopMap[govRoute.stops.first]!;
    final dest = busStopMap[route.stops.last]!;
    final govDest = govStopMap[govRoute.stops.last]!;

    // Check if the origins are the same
    final originDistance = BuilderUtils.distance(
      origin.latLng.toLatLong(),
      govOrigin.latLng.toLatLong(),
    );
    if (originDistance > _jointRouteErrorDistanceMeters) return false;

    // Check if the destinations are the same
    final destDistance = BuilderUtils.distance(
      dest.latLng.toLatLong(),
      govDest.latLng.toLatLong(),
    );
    if (destDistance > _jointRouteErrorDistanceMeters) return false;

    // For circular route, gov route omits the last stop. Check if the company
    // route destination is the same as the gov route origin.
    if (govRoute.originE == govRoute.destE) {
      final terminalDistance = BuilderUtils.distance(
        govOrigin.latLng.toLatLong(),
        dest.latLng.toLatLong(),
      );
      if (terminalDistance <= _circularRouteErrorDistanceMeters) return true;
    }
    return true;
  }

  static bool _areStopsMatch(CompanyBusRoute route, GovBusRoute govRoute) {
    return true;
  }
}
