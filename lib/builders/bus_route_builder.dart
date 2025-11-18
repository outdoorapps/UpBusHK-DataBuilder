import 'dart:math';

import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
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
  static const double _govRouteMatchRadiusMeters = 220.0; // 38X cap
  static const double _jointRouteMatchingRadiusMeters = 160.0;
  static const double _circularRouteMatchingRadiusMeters = 250.0; // CTB 25 cap
  static const double _stopPairingRadiusMeters = 50.0;

  static late final Map<int, GovStop> govStopMap;
  static late final Map<String, BusStop> busStopMap;
  static late final List<GovBusRoute> govRoutes;

  static Future<void> build() async {
    // await GovBusBuilder.build(clearPreviousData: true); //todo

    final govStops = await builderIsar.govStops.where().findAll();
    govStopMap = Map.fromEntries(govStops.map((e) => MapEntry(e.stopId, e)));

    final busStops = await isar.busStops.where().findAll();
    busStopMap = Map.fromEntries(busStops.map((e) => MapEntry(e.stopId, e)));

    govRoutes = await builderIsar.govBusRoutes.where().findAll();

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

    // KMB+CTB or LWB+CTB
    final govJointRoutes = govRoutes.where((e) => e.companyCode.contains('+'));

    final jointRoutes = <BusRoute>[];
    for (final route in govJointRoutes) {
      final potentials = kmbCompanyRoutes.where(
        (e) => e.number == route.number,
      );
      if (potentials.isEmpty) {
        print('Joint route: ${route.number} has no matching KMB/LWB route');
        continue;
      }
      final boundMatched = potentials.where((e) => _isGovBoundMatch(e, route));
      if (boundMatched.isEmpty) {
        print(
          'Joint route: ${route.number} has no bound matching KMB/LWB route',
        );
        continue;
      }
      final kmbRoute = boundMatched.length == 1
          ? boundMatched.first
          : _getCompanyRouteWithMostPairingStops(route, boundMatched.toList());
      kmbCompanyRoutes.remove(kmbRoute);

      final ctbRoute = await _matchCtbRoute(kmbRoute, ctbCompanyRoutes);
      if (ctbRoute != null) {
        print(
          'Joint route: ${route.number}-${kmbRoute.bound}-${kmbRoute.serviceType}'
          ' has no bound matching CTB route',
        );
      } else {
        ctbCompanyRoutes.remove(ctbRoute);
      }

      // todo 107P use CTB as primary reference
      final jointRoute = _buildRoute(kmbRoute, route).copyWith(
        secondaryBound: ctbRoute?.bound,
        secondaryStops: ctbRoute?.stops ?? [],
      );
      jointRoutes.add(jointRoute);
    }

    for (final route in kmbCompanyRoutes) {
      final govRoute = await _matchGovRoute(route);

      if (govRoute == null) {
      } else {
        if (govRoute.companyCode.contains('+')) {
          final ctbRoute = await _matchCtbRoute(route, ctbCompanyRoutes);
          if (ctbRoute != null) {
            print(
              'No ctb route found for joint route: ${route.number}, ${route.bound}, ${route.serviceType}',
            );
          } else {}
        }
      }
    }
    final kmbRoutes = _buildRoutes(kmbCompanyRoutes);
    final ctbRoutes = _buildRoutes(ctbCompanyRoutes);
    final nlbRoutes = _buildRoutes(nlbCompanyRoutes);
    final mtrbRoutes = _buildRoutes(mtrbCompanyRoutes);

    _printMatchCount(jointRoutes);
    _printMatchCount(kmbRoutes);
    _printMatchCount(ctbRoutes);
    _printMatchCount(nlbRoutes);
    _printMatchCount(mtrbRoutes);

    final routes = <BusRoute>[];
    //todo write to isar
  }

  static void _printMatchCount(List<BusRoute> routes) {
    final company = routes.first.companies.length == 1
        ? routes.first.companies.first.name
        : 'Joint';
    final matchCount = routes.where((e) => e.govRouteId != null).length;
    final unmatchCount = routes.length - matchCount;

    print(
      '$company:${routes.length} (matched:$matchCount, unmatch:$unmatchCount)',
    );
  }

  // static List<BusRoute> _buildJointRoutes(List<GovBusRoute> routes) {
  //
  // }

  static List<BusRoute> _buildRoutes(List<CompanyBusRoute> routes) {
    final busRoutes = <BusRoute>[];

    for (final route in routes) {
      final govRoute = _matchGovRoute(route);
      final busRoute = _buildRoute(route, govRoute);
      busRoutes.add(busRoute);
    }
    return busRoutes;
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
      originE: route.originEn,
      originC: route.originChiT,
      destE: route.destEn,
      destC: route.destChiT,
      fullFare: govRoute?.fullFare,
      stops: route.stops,
      secondaryStops: [],
      fares: govRoute?.fares ?? [],
      serviceType: route.serviceType,
      nlbRouteId: route.nlbRouteId,
      govRouteId: govRoute?.routeId,
      trackId: null,
    );
  }

  static GovBusRoute? _matchGovRoute(CompanyBusRoute route) {
    // 1. Filter by company & number
    final isKmb = route.company == Company.KMB;
    final potentials = govRoutes.where(
      (e) => e.number == route.number && isKmb
          ? e.companyCode.contains('KMB') || e.companyCode.contains('LWB')
          : e.companyCode.contains(route.company.name),
    );
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

  static CompanyBusRoute _getCompanyRouteWithMostPairingStops(
    GovBusRoute route,
    List<CompanyBusRoute> companyRoutes,
  ) {
    final govRouteToPairStopCount = companyRoutes.map(
      (e) => MapEntry(e, _countMatchingStops(e, route)),
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

  static Future<CompanyBusRoute?> _matchCtbRoute(
    CompanyBusRoute route,
    List<CompanyBusRoute> ctbRoutes,
  ) async {
    // 1. Filter by number
    final potentials = ctbRoutes.where((e) => e.number == route.number);
    if (potentials.isEmpty) return null;

    // 2. Match bound
    final boundMatched = potentials.where((e) => _isBoundMatch(route, e));
    return boundMatched.isEmpty ? null : boundMatched.first;
  }

  static bool _isBoundMatch(CompanyBusRoute route, CompanyBusRoute ctbRoute) {
    final origin = busStopMap[route.stops.first]!;
    final govOrigin = busStopMap[ctbRoute.stops.first]!;
    final dest = busStopMap[route.stops.last]!;
    final govDest = busStopMap[ctbRoute.stops.last]!;

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
    return true;
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
