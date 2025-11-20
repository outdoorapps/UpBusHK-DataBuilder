import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop.dart';
import 'package:up_bus_hk_core/isar/models/bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_data_builder/extension/gov_bus_route_x.dart';
import 'package:up_bus_hk_data_builder/extension/lat_lng_x.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/utils/builder_utils.dart';

class BusRouteBuilder {
  static const double _govRouteMatchRadiusMeters = 220.0; // 38X cap
  static const double _jointRouteMatchingRadiusMeters = 160.0;
  static const double _circularRouteMatchingRadiusMeters = 250.0; // CTB 25 cap
  static const double _stopPairingRadiusMeters = 50.0;

  static late final Map<int, GovStop> govStopMap;
  static late final Map<String, BusStop> busStopMap;
  static final allRoutes = <BusRoute>[];

  static Future<void> build() async {
    // await GovBusBuilder.build(clearPreviousData: true); //todo
    await isar.writeTxn(() => isar.busRoutes.clear()); //todo
    allRoutes.clear();

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

    final nlbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.NLB)
        .findAll();

    final mtrbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.MTRB)
        .findAll();

    await _buildRoutes(kmbCompanyRoutes);
    await _buildRoutes(ctbCompanyRoutes);
    await _buildRoutes(nlbCompanyRoutes);
    await _buildRoutes(mtrbCompanyRoutes);

    // Print stats
    // final routes = await isar.busRoutes.where().findAll();
    Company.values.forEach((e) => _printMatchCount(allRoutes, e));

    final govRoutes = await builderIsar.govBusRoutes.where().findAll();
    final govJointRoutes = govRoutes.where((e) => e.isJointRoute);
    final jointRoutes = allRoutes.where((e) => e.companies.length > 1);
    // todo check joint routes without secondaries
    // todo negative unmatch routes
    print(
      'Joint:${govJointRoutes.length} (matched:${jointRoutes.length}, unmatch:${govJointRoutes.length - jointRoutes.length})',
    );
    //todo write to isar
  }

  static void _printMatchCount(List<BusRoute> routes, Company company) {
    final routesOfCompany = routes.where(
      (e) => e.companies.length == 1 && e.companies.first == company,
    );
    final matchCount = routesOfCompany
        .where((e) => e.govRouteKey != null)
        .length;
    final unmatchCount = routesOfCompany.length - matchCount;

    print(
      '${company.name}:${routesOfCompany.length} (matched:$matchCount, unmatch:$unmatchCount)',
    );
  }

  static Future<void> _buildRoutes(List<CompanyBusRoute> routes) async {
    for (final route in routes) {
      final govRoute = await _matchGovRoute(route);
      if (govRoute != null && govRoute.isJointRoute) {
        final existing = await isar.busRoutes
            .where()
            .govRouteKeyEqualTo(govRoute.key)
            .findFirst();

        // todo 107P use CTB as primary reference
        if (existing != null) {
          final updated = existing.copyWith(
            secondaryBound: route.bound,
            secondaryStops: route.stops,
          );
          print('Original: ${existing.id}, Updating ${updated.id}');
          // await isar.writeTxn(() => isar.busRoutes.put(updated));
          allRoutes.remove(existing);
          allRoutes.add(updated);
          continue;
        }
      }
      final busRoute = _buildRoute(route, govRoute);
      allRoutes.add(busRoute);
      // await isar.writeTxn(() async => isar.busRoutes.put(busRoute));
    }
  }

  static BusRoute _buildRoute(CompanyBusRoute route, GovBusRoute? govRoute) {
    final companies = govRoute == null
        ? [route.company]
        : govRoute.companyCode
              .split('+')
              .map((e) => Company.values.byName(e))
              .toList();

    final routeId = _generateRouteId(
      companies: companies,
      number: route.number,
      bound: route.bound,
      serviceType: route.serviceType,
      nlbRouteId: null,
    );
    // todo fill fares
    return BusRoute(
      routeId: routeId,
      companies: companies,
      number: route.number,
      bound: route.bound,
      secondaryBound: null,
      originE: route.originE,
      originC: route.originC,
      destE: route.destE,
      destC: route.destC,
      fullFare: govRoute?.fullFare,
      stops: route.stops,
      secondaryStops: [],
      fares: govRoute?.fares ?? [],
      serviceType: route.serviceType,
      nlbRouteId: route.nlbRouteId,
      govRouteKey: govRoute?.key,
      trackId: null,
    );
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
    if (potentials.isEmpty) return null;

    // 2. Match bound
    // If there are more than one candidates, return the one with the most
    // pairing stops
    final boundMatched = potentials.where((e) => _isGovBoundMatch(route, e));
    return switch (boundMatched.length) {
      0 => null,
      1 => boundMatched.first,
      _ => _getGovRouteWithMostPairingStops(route, boundMatched.toList()),
    };
  }

  static bool _isGovBoundMatch(CompanyBusRoute route, GovBusRoute govRoute) {
    final origin = busStopMap[route.stops.first]!;
    final govOrigin = govStopMap[govRoute.stops.first]!;
    final dest = busStopMap[route.stops.last]!;
    final govDest = govStopMap[govRoute.stops.last]!;

    // I. Check if the origins are the same
    final originDistance = BuilderUtils.distance(
      origin.latLng.toLatLong(),
      govOrigin.latLng.toLatLong(),
    );
    if (originDistance > _govRouteMatchRadiusMeters) return false;

    // II. Check if the destinations are the same
    final destDistance = BuilderUtils.distance(
      dest.latLng.toLatLong(),
      govDest.latLng.toLatLong(),
    );
    if (destDistance > _govRouteMatchRadiusMeters) return false;

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

  static String _generateRouteId({
    required List<Company> companies,
    required String number,
    required Bound bound,
    int? serviceType,
    String? nlbRouteId,
  }) {
    // Deterministic company ordering for consistent IDs
    final companyCode = companies.map((e) => e.name).sorted().join(':');
    final serviceTypeText = '${serviceType ?? ''}';
    final routeId = companies.contains(Company.NLB) ? nlbRouteId ?? '' : '';
    final parts = [
      companyCode,
      number,
      bound.name,
      serviceTypeText,
      routeId,
    ].where((e) => e.isNotEmpty);
    return parts.join('-');
  }
}
