import 'package:collection/collection.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_data_builder/builders/mtrb_parser.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/json/ctb_route.dart';
import 'package:up_bus_hk_data_builder/json/kmb_route.dart';
import 'package:up_bus_hk_data_builder/network/data_services.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';
import 'package:up_bus_hk_data_builder/utils/async_utils.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';
import 'package:up_bus_hk_data_builder/utils/progress_tracker.dart';

class CompanyRouteBuilder {
  /// Fetch from the online APIs to build a list of [CompanyBusRoute] and save
  /// them to Isar.
  static Future<void> build({bool clearPreviousData = false}) async {
    if (clearPreviousData) {
      await builderIsar.writeTxn(
        () async => builderIsar.companyBusRoutes.clear(),
      );
    }

    final kmbRoutes = await _buildKmbRoutes();
    final ctbRoutes = await _buildCtbRoutes();
    final nlbRoutes = await _buildNlbRoutes();
    final mtrbRoutes = await _buildMtrbRoutes();

    final companyRoutes = [
      ...kmbRoutes,
      ...ctbRoutes,
      ...nlbRoutes,
      ...mtrbRoutes,
    ];
    companyRoutes.sort((a, b) => a.number.compareTo(b.number));
    await builderIsar.writeTxn(
      () async => builderIsar.companyBusRoutes.putAll(companyRoutes),
    );

    print(
      '- KMB routes: ${kmbRoutes.length}'
      '\n- CTB routes: ${ctbRoutes.length}'
      '\n- NLB routes: ${nlbRoutes.length}'
      '\n- MTRB routes: ${mtrbRoutes.length}'
      '\n- Total: ${companyRoutes.length}',
    );
  }

  static Future<List<CompanyBusRoute>> _buildKmbRoutes() async {
    final results = await Benchmark.executeAsync(
      'Getting KMB routes',
      WebServices.kmb.getRoutes,
    );
    final routes = results.data;

    final builtRoutes = <CompanyBusRoute>[];
    final pending = routes.map((r) => r.key).toSet();

    await WebServices.retryBatch<String>(
      pending: pending,
      pendingTypeLabel: "KMB routes",
      work: (batchKeys) async {
        final batchRoutes = batchKeys
            .map((key) => routes.firstWhere((r) => r.key == key))
            .toList();
        final results = await _buildKmbRoutesBatch(batchRoutes);
        builtRoutes.addAll(results);

        return batchKeys.toSet();
      },
    );
    return builtRoutes;
  }

  /// Build CompanyBusRoute for a batch of KMB route models.
  /// Includes progress tracking and concurrent execution.
  static Future<List<CompanyBusRoute>> _buildKmbRoutesBatch(
    List<KmbRoute> batch,
  ) async {
    return AsyncUtils.mapAsyncWithProgress(
      items: batch,
      label: "Building KMB routes",
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
  static Future<List<CompanyBusRoute>> _buildCtbRoutes() async {
    final response = await Benchmark.executeAsync(
      'Getting CTB routes',
      WebServices.gov.getCtbRoutes,
    );
    final routes = response.data;

    final builtRoutes = <CompanyBusRoute>[];
    final pending = routes
        .expand((route) => Bound.values.map((b) => route.key(b)))
        .toSet();

    await WebServices.retryBatch<String>(
      pending: pending,
      pendingTypeLabel: "CTB routes",
      work: (batchKeys) async {
        // Convert retry keys back to real CtbRoute+Bound pairs
        final batchPairs = batchKeys.map((key) {
          final parts = key.split("-");
          final routeNum = parts[0];
          final boundLabel = parts[1];

          final route = routes.firstWhere((r) => r.route == routeNum);
          final bound = Bound.values.firstWhere((b) => b.label == boundLabel);
          return (route, bound);
        }).toList();

        // Process batch
        final results = await _buildCtbRouteBatch(batchPairs);

        // Only add routes with stops (routes with no stops indicate an invalid
        // bound).
        builtRoutes.addAll(results.where((e) => e.stops.isNotEmpty));
        return results.map((r) => '${r.number}-${r.bound.label}').toSet();
      },
    );
    return builtRoutes;
  }

  static Future<List<CompanyBusRoute>> _buildCtbRouteBatch(
    List<(CtbRoute route, Bound bound)> batch,
  ) async {
    final results =
        await AsyncUtils.mapAsyncWithProgress<
          (CtbRoute, Bound),
          CompanyBusRoute?
        >(
          items: batch,
          label: "Building CTB routes",
          worker: (pair) async {
            final (route, bound) = pair;
            final stops = await DataServices.getCtbRouteStops(
              route.route,
              bound.label,
            );
            // For bounds that doesn't exist, it will have empty stops, return
            // a CompanyBusRoute with empty stops to distinguish it between an
            // error (which returns null).
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

  static Future<List<CompanyBusRoute>> _buildNlbRoutes() async {
    final response = await Benchmark.executeAsync(
      'Getting NLB routes',
      WebServices.gov.getNlbRoutes,
    );
    final routes = response.routes;
    routes.sortBy((r) => int.tryParse(r.routeId) ?? 0); // Sort by routeId

    final List<CompanyBusRoute> nlbCompanyBusRoutes = [];
    final tracker = ProgressTracker(
      label: 'Building NLB routes',
      total: routes.length,
    );

    // Process in for loop to preserve sequence for bound resolution.
    for (final route in routes) {
      // Get route stops (blocking sequentially for bound logic to work)
      final response = await WebServices.gov.getNlbRouteStops(route.routeId);
      final stops = response.stops;

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

  static Future<List<CompanyBusRoute>> _buildMtrbRoutes() async {
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
            originEn: origin.nameE,
            originChiT: origin.nameC,
            destEn: dest.nameE,
            destChiT: dest.nameC,
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
