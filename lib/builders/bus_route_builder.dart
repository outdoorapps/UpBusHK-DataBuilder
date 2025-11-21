import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop.dart';
import 'package:up_bus_hk_core/isar/embedded/bus_stop_fare.dart';
import 'package:up_bus_hk_core/isar/embedded/gov_stop_fare.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_core/isar/models/bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_data_builder/extension/bus_route_x.dart';
import 'package:up_bus_hk_data_builder/extension/gov_bus_route_x.dart';
import 'package:up_bus_hk_data_builder/extension/lat_lng_x.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/utils/builder_utils.dart';
import 'package:up_bus_hk_data_builder/utils/patch.dart';
import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';

class BusRouteBuilder {
  static const double _govRouteMatchRadiusMeters = 220.0; // 38X cap
  static const double _jointRouteMatchingRadiusMeters = 160.0;
  static const double _circularRouteMatchingRadiusMeters = 250.0; // CTB 25 cap
  static const double _stopPairingRadiusMeters = 50.0;

  static late final Set<String> _jointRouteNumbers;
  static late final Map<int, GovStop> _govStopMap;
  static late final Map<String, BusStop> _busStopMap;
  static final _matchedGovRouteKeys = <String>{};

  static Future<void> build({bool clearPreviousData = false}) async {
    if (clearPreviousData) {
      await isar.writeTxn(() => isar.busRoutes.clear());
    }

    final govRoutes = await builderIsar.govBusRoutes.where().findAll();
    final govJointRoutes = govRoutes.where((e) => e.isJointRoute).toList();
    _jointRouteNumbers = Set.unmodifiable(
      govJointRoutes.map((e) => e.number).toSet(),
    );

    final govStops = await builderIsar.govStops.where().findAll();
    _govStopMap = Map.unmodifiable(
      Map.fromEntries(govStops.map((e) => MapEntry(e.stopId, e))),
    );

    final busStops = await isar.busStops.where().findAll();
    _busStopMap = Map.unmodifiable(
      Map.fromEntries(busStops.map((e) => MapEntry(e.stopId, e))),
    );

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
    await _patchFares();
    await _printStats(govJointRoutes);
    // todo 107P use CTB as primary reference
  }

  static Future<void> _patchFares() async {
    final routes = await isar.busRoutes
        .filter()
        .serviceTypeIsNotNull()
        .findAll();

    final fareGroups = groupBy(routes, (e) => e.fareGroupKey);
    final updatedRoutes = <BusRoute>{};
    final tracker = ProgressTracker(label: 'Patching bus fare data');

    await Future.forEach(fareGroups.values, (routes) async {
      if (routes.length == 1) return;

      final notFullyPopulatedRoutes = routes.where(
        (e) => e.stopFares
            .sublist(0, e.stopFares.length - 1) // Ignore the last item
            .any((e) => e.fare == null),
      );
      if (notFullyPopulatedRoutes.isEmpty) return;

      final populatedRoutes = routes
          .where(
            (e) => e.stopFares
                .sublist(0, e.stopFares.length - 1) // Ignore the last item
                .every((e) => e.fare != null),
          )
          .toList();
      if (populatedRoutes.isEmpty) return;

      // Pick the route with the most stop fares
      final populatedRoute = populatedRoutes.reduce(
        (a, b) => a.stopFares.length > b.stopFares.length ? a : b,
      );

      notFullyPopulatedRoutes.forEach((r) {
        final populatedStopFares = List.from(populatedRoute.stopFares);
        r.stopFares.forEach((stopFare) {
          if (stopFare.fare == null) {
            final populatedStopFare = populatedStopFares.firstWhereOrNull(
              (e) => e.stopId == stopFare.stopId,
            );
            if (populatedStopFare != null) {
              stopFare.fare = populatedStopFare?.fare;
              populatedStopFares.remove(populatedStopFare);
              updatedRoutes.add(r);
            }
          }
        });
      });
      await tracker.increment(count: notFullyPopulatedRoutes.length);
    });

    await isar.writeTxn(
      () async => isar.busRoutes.putAll(updatedRoutes.toList()),
    );
    tracker.finish();
  }

  static Future<void> _printStats(List<GovBusRoute> govJointRoutes) async {
    final routes = await isar.busRoutes.where().findAll();
    Company.values.forEach((e) => _printMatchCount(routes, e));

    final jointRoutes = routes.where((e) => e.companies.length > 1);
    final matchedGovJointRoutesIds = jointRoutes
        .map((e) => e.govRouteKey)
        .whereType<String>()
        .toSet();
    final unmatchedGovJointRoutes = govJointRoutes.where(
      (e) => !matchedGovJointRoutesIds.contains(e.key),
    );
    print(
      'Joint:${matchedGovJointRoutesIds.length} '
      '(Total:${govJointRoutes.length}, '
      'unused:${unmatchedGovJointRoutes.length})',
    );
    // Log unmatched gov joint routes
    unmatchedGovJointRoutes
        .where((e) => !Patch.accountedJointRoute.contains(e.key))
        .forEach((e) => print('${e.number},${e.key}'));

    // Log routes with missing secondary info
    final noSecondary = jointRoutes.where((e) => e.jointBound == null);
    if (noSecondary.isNotEmpty) {
      print('Joint routes missing secondary info: ${noSecondary.length}');
      noSecondary.forEach((e) => print('- ${e.routeId}'));
    }
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
      '${company.name}:${routesOfCompany.length} (matched:$matchCount, '
      'unmatched:$unmatchCount)',
    );
  }

  static Future<void> _buildRoutes(List<CompanyBusRoute> routes) async {
    final tracker = ProgressTracker(
      label: 'Creating ${routes.first.company.name} bus routes',
    );
    for (final route in routes) {
      // Joint route for CTB should have been created, skip
      if (route.company == Company.CTB && _isJointRoute(route)) continue;

      final govRoute = await _matchGovRoute(route);

      final busRoute = govRoute != null && govRoute.isJointRoute
          ? await _buildJointRoute(route, govRoute)
          : _buildRoute(route, govRoute);

      if (busRoute != null) {
        await isar.writeTxn(() async => isar.busRoutes.put(busRoute));
        await tracker.increment();
      }
    }
    tracker.finish();
  }

  static Future<BusRoute?> _buildJointRoute(
    CompanyBusRoute route,
    GovBusRoute govRoute,
  ) async {
    // 1. Find the matching joint route
    final isKmb = route.company == Company.KMB;
    final potentials = await builderIsar.companyBusRoutes
        .where()
        .numberEqualTo(route.number)
        .filter()
        .companyEqualTo(isKmb ? Company.CTB : Company.KMB)
        .findAll();
    final jointRoute = potentials.firstWhereOrNull(
      (e) => _isBoundMatch(route, e),
    );
    if (jointRoute == null) {
      print('No pairing route found for route:$route');
      return null;
    }

    // 2. Build the stop-fare list
    final jointStops = List.from(jointRoute.stops);

    final stopFares = route.stops.map((stop) {
      // 2a. For each stop, find the closest joint stop
      // For each stop, create MapEntries of joint stops to distance
      final latLong1 = _busStopMap[stop]!.latLng.toLatLong();
      final distances = jointStops.map((j) {
        final potentialStop = _busStopMap[j]!;
        final latLong2 = potentialStop.latLng.toLatLong();
        return MapEntry(j, BuilderUtils.distance(latLong1, latLong2));
      });

      // Find the closest stop
      final closest = distances.reduce((a, b) => a.value < b.value ? a : b);
      final closestStopId = closest.key;
      final closestDistance = closest.value;

      String? jointStopId;
      if (closestDistance <= _stopPairingRadiusMeters) {
        jointStopId = closestStopId;
        jointStops.remove(closestStopId); // Remove id to avoid double matching
      }
      return BusStopFare(stopId: stop, jointStopId: jointStopId);
    }).toList();

    return _buildRoute(
      route,
      govRoute,
      jointBound: jointRoute.bound,
      stopFares: stopFares,
    );
  }

  static BusRoute _buildRoute(
    CompanyBusRoute route,
    GovBusRoute? govRoute, {
    Bound? jointBound,
    List<BusStopFare>? stopFares,
  }) {
    // Create the company list
    final companies = govRoute == null
        ? [route.company]
        : govRoute.companyCode
              .split('+')
              .map((e) => Company.values.byName(e))
              .toList();

    // Create the BusStopFare list
    final List<BusStopFare> busStopFares = _buildStopFares(
      route,
      govRoute: govRoute,
      jointStops: stopFares,
    );

    return BusRoute(
      companies: companies,
      number: route.number,
      bound: route.bound,
      jointBound: jointBound,
      originE: route.originE,
      originC: route.originC,
      destE: route.destE,
      destC: route.destC,
      fullFare: govRoute?.fullFare,
      stopFares: busStopFares,
      serviceType: route.serviceType,
      nlbRouteId: route.nlbRouteId,
      govRouteKey: govRoute?.key,
    );
  }

  static List<BusStopFare> _buildStopFares(
    CompanyBusRoute route, {
    GovBusRoute? govRoute,
    List<BusStopFare>? jointStops,
  }) {
    if (govRoute == null) {
      return List.generate(
        route.stops.length,
        (i) => BusStopFare(stopId: route.stops[i]),
      );
    } else {
      final allFullFare = govRoute.stopFares.every(
        (e) => e.fare == govRoute.fullFare,
      );
      final sameLength = route.stops.length == govRoute.stopFares.length;
      final stopFaresRemaining = List<GovStopFare>.from(govRoute.stopFares);

      return List.generate(route.stops.length, (i) {
        final stopId = route.stops[i];
        final double? fare;

        if (allFullFare) {
          fare = govRoute.fullFare; // Flat full fare
        } else if (sameLength) {
          fare = govRoute.stopFares[i].fare; // Direct matching
        } else {
          // Closest stop-based fare
          final (index, f) = _getStopBasedFare(stopId, stopFaresRemaining);
          if (index != null) {
            stopFaresRemaining.removeAt(index);
            fare = f;
          } else {
            fare = null;
          }
        }
        return BusStopFare(
          stopId: route.stops[i],
          jointStopId: jointStops?[i].jointStopId,
          fare: fare,
        );
      });
    }
  }

  static (int?, double?) _getStopBasedFare(
    String busStopId,
    List<GovStopFare> govStopFares,
  ) {
    if (govStopFares.isEmpty) return (null, null);

    final stop = _busStopMap[busStopId]!;

    final distances = govStopFares.map((g) {
      final govStop = _govStopMap[g.stopId]!;
      final d = BuilderUtils.distance(
        stop.latLng.toLatLong(),
        govStop.latLng.toLatLong(),
      );
      return MapEntry(g, d);
    }).toList();

    // choose closest
    final closest = distances.reduce((a, b) => a.value < b.value ? a : b);

    double? fare;
    int? index;
    if (closest.value <= _stopPairingRadiusMeters) {
      fare = closest.key.fare;
      index = govStopFares.indexOf(closest.key);
    }
    return (index, fare);
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

    // Exclude gov routes that has already been matched to a company bus route
    potentials.removeWhere((e) => _matchedGovRouteKeys.contains(e.key));
    if (potentials.isEmpty) return null;

    // 2. Match bound
    // If there are more than one candidates, return the one with the most
    // pairing stops
    final boundMatched = potentials.where((e) => _isGovBoundMatch(route, e));
    final matchedGovRoute = switch (boundMatched.length) {
      0 => null,
      1 => boundMatched.first,
      _ => _getGovRouteWithMostPairingStops(route, boundMatched.toList()),
    };

    if (matchedGovRoute != null) _matchedGovRouteKeys.add(matchedGovRoute.key);
    return matchedGovRoute;
  }

  static bool _isGovBoundMatch(CompanyBusRoute route, GovBusRoute govRoute) {
    final origin = _busStopMap[route.stops.first]!;
    final govOrigin = _govStopMap[govRoute.stops.first]!;
    final dest = _busStopMap[route.stops.last]!;
    final govDest = _govStopMap[govRoute.stops.last]!;

    // I. Check if the origins are the same
    final originMatch = _isLatLngMatch(
      origin.latLng,
      govOrigin.latLng,
      _govRouteMatchRadiusMeters,
    );
    if (!originMatch) return false;

    // II. Check if the destinations are the same
    final destMatch = _isLatLngMatch(
      dest.latLng,
      govDest.latLng,
      _govRouteMatchRadiusMeters,
    );
    if (!destMatch) return false;

    // III. For a circular route, gov route omits the last stop. Check if the
    // company route destination is the same as the gov route origin.
    if (govRoute.originE == govRoute.destE) {
      final terminalMatch = _isLatLngMatch(
        dest.latLng,
        govOrigin.latLng,
        _circularRouteMatchingRadiusMeters,
      );
      if (terminalMatch) return true;
    }
    return true;
  }

  /// Check if two [CompanyBusRoute]s' bounds match with each other. If either
  /// the origins or the destinations match, return true.
  static bool _isBoundMatch(CompanyBusRoute route1, CompanyBusRoute route2) {
    final origin1 = _busStopMap[route1.stops.first]!;
    final origin2 = _busStopMap[route2.stops.first]!;
    final dest1 = _busStopMap[route1.stops.last]!;
    final dest2 = _busStopMap[route2.stops.last]!;
    return _isLatLngMatch(
          origin1.latLng,
          origin2.latLng,
          _jointRouteMatchingRadiusMeters,
        ) ||
        _isLatLngMatch(
          dest1.latLng,
          dest2.latLng,
          _jointRouteMatchingRadiusMeters,
        );
  }

  /// Check if two [LatLng]s are within a given [radius] in meters
  /// [radius] Matching radius in meters
  static bool _isLatLngMatch(LatLng latLng1, LatLng latLng2, double radius) =>
      BuilderUtils.distance(latLng1.toLatLong(), latLng2.toLatLong()) <= radius;

  /// Find the [GovBusRoute] with the most stops that are within
  /// [_stopPairingRadiusMeters] with the stops in [route].
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

  /// Find the number of stops in [route] and [govRoute] that are within
  /// [_stopPairingRadiusMeters] of each other.
  static int _countMatchingStops(CompanyBusRoute route, GovBusRoute govRoute) {
    int count = 0;
    final govStops = govRoute.stops.toList();

    route.stops.forEach((s) {
      final busStop = _busStopMap[s]!;
      final latLong = busStop.latLng.toLatLong();

      final distances = govStops.map((e) {
        final govStop = _govStopMap[e]!;
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

  static bool _isJointRoute(CompanyBusRoute route) =>
      (route.company == Company.KMB || route.company == Company.CTB) &&
      _jointRouteNumbers.contains(route.number);
}
