import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/builders/mtrb_parser.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/company_bus_route.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/utils/async_utils.dart';
import 'package:upbushk_data_builder/utils/benchmark.dart';
import 'package:upbushk_data_builder/utils/progress_tracker.dart';

class CompanyRouteBuilder {
  static Future<List<CompanyBusRoute>> buildKmbRoutes() async {
    final routes = await Benchmark.executeAsync(
      'Getting KMB routes',
      DataServices.getKmbRoutes,
    );
    return AsyncUtils.mapAsyncWithProgress(
      items: routes,
      label: "Building KMB routes",
      step: 50,
      worker: (e) async {
        final stops = await DataServices.getKmbRouteStops(
          e.route,
          e.bound.label,
          e.serviceType,
        );

        return CompanyBusRoute(
          company: Company.KMB,
          number: e.route,
          bound: e.bound,
          originEn: e.origEn,
          originChiT: e.origTc,
          destEn: e.destEn,
          destChiT: e.destTc,
          serviceType: int.tryParse(e.serviceType),
          nlbRouteId: null,
          stops: stops.map((s) => s.stopId).toList(),
        );
      },
    );
  }

  /// Build [CompanyBusRoute] for CTB routes. SinceCTB does not return bound
  /// info in its route API, we will need to try get route stops for both
  /// bounds. If a bound doesn't exist, it will return no stops and we will
  /// skip that bound.
  static Future<List<CompanyBusRoute>> buildCtbRoutes() async {
    final routes = await Benchmark.executeAsync(
      'Getting CTB routes',
      DataServices.getCtbRoutes,
    );

    // Expand into (route, bound) pairs
    final pairs = routes
        .expand((route) => Bound.values.map((bound) => (route, bound)))
        .toList();

    final results = await AsyncUtils.mapAsyncWithProgress(
      items: pairs,
      label: "Building CTB routes",
      step: 50,
      worker: (pair) async {
        final (route, bound) = pair;
        final stops = await DataServices.getCtbRouteStops(
          route.route,
          bound.label,
        );

        if (stops.isEmpty) return null; // ignore missing bound

        return CompanyBusRoute(
          company: Company.CTB,
          number: route.route,
          bound: bound,
          originEn: bound == Bound.O ? route.origEn : route.destEn,
          originChiT: bound == Bound.O ? route.origTc : route.destTc,
          destEn: bound == Bound.O ? route.destEn : route.origEn,
          destChiT: bound == Bound.O ? route.destTc : route.origTc,
          serviceType: null,
          nlbRouteId: null,
          stops: stops.map((s) => s.stopId).toList(),
        );
      },
    );

    return results.whereType<CompanyBusRoute>().toList();
  }

  static Future<List<CompanyBusRoute>> buildNlbRoutes() async {
    final routes = await Benchmark.executeAsync(
      'Getting NLB routes',
      DataServices.getNlbRoutes,
    );
    routes.sortBy((r) => int.tryParse(r.routeId) ?? 0); // Sort by routeId

    final List<CompanyBusRoute> nlbCompanyBusRoutes = [];
    final tracker = ProgressTracker(
      label: 'Building NLB routes',
      total: routes.length,
      step: 1,
    );

    // Process in for loop to preserve sequence for bound resolution.
    for (final route in routes) {
      // Extract origin and destination names
      final nameEParts = route.routeNameE.split('>');
      final nameCParts = route.routeNameC.split('>');

      final originEn = nameEParts.first.trim();
      final destEn = nameEParts.length > 1 ? nameEParts[1].trim() : '';
      final originChiT = nameCParts.first.trim();
      final destChiT = nameCParts.length > 1 ? nameCParts[1].trim() : '';

      // Determine bound
      // If route number hasn't been added: outbound
      // If route number has been added: determined by origin and destination
      final existing = nlbCompanyBusRoutes
          .where((r) => r.number == route.number)
          .toList();

      final bound = existing.isEmpty
          ? Bound.O
          : (existing.any((r) => r.originEn == originEn || r.destEn == destEn)
                ? Bound.O
                : Bound.I);

      // Get route stops (blocking sequentially for bound logic to work)
      final stops = await DataServices.getNlbRouteStops(route.routeId);

      nlbCompanyBusRoutes.add(
        CompanyBusRoute(
          company: Company.NLB,
          number: route.number,
          bound: bound,
          originEn: originEn,
          originChiT: originChiT,
          destEn: destEn,
          destChiT: destChiT,
          serviceType: null,
          nlbRouteId: route.routeId,
          stops: stops.map((s) => s.stopId).toList(),
        ),
      );
      await tracker.increment();
    }
    return nlbCompanyBusRoutes;
  }

  static Future<List<CompanyBusRoute>> buildMtrbRoutes() async {
    final List<CompanyBusRoute> mtrbCompanyBusRoutes = [];

    await Benchmark.executeAsync('Building MTRB routes', () async {
      final mtrbRouteMap = await MtrbParser.parseMtrbData(
        ProjectPaths.mtrbDataPath,
      );

      mtrbRouteMap.forEach((routeName, boundMap) {
        boundMap.forEach((bound, stops) {
          if (stops.isEmpty) return;

          final origin = stops.first;
          final dest = stops.last;

          final route = CompanyBusRoute(
            company: Company.MTRB,
            number: routeName,
            bound: bound,
            originEn: origin.engName,
            originChiT: origin.chiTName,
            destEn: dest.engName,
            destChiT: dest.chiTName,
            serviceType: null,
            nlbRouteId: null,
            stops: stops.map((s) => s.stopId).toList(),
          );
          mtrbCompanyBusRoutes.add(route);
        });
      });
    });

    return mtrbCompanyBusRoutes;
  }
}
