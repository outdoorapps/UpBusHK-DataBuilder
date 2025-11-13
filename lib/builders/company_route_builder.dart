import 'dart:io';

import 'package:collection/collection.dart';
import 'package:upbushk_data_builder/builders/mtrb_parser.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/company_bus_route.dart';
import 'package:upbushk_data_builder/network/data_services.dart';

class CompanyRouteBuilder {
  static Future<List<CompanyBusRoute>> buildKmbRoutes() async {
    final routes = await DataServices.getKmbRoutes();
    return await Future.wait(
      routes.map((e) async {
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
          stops: stops.map((e) => e.stopId).toList(),
        );
      }),
    );
  }

  /// Build [CompanyBusRoute] for CTB routes. SinceCTB does not return bound
  /// info in its route API, we will need to try get route stops for both
  /// bounds. If a bound doesn't exist, it will return no stops and we will
  /// skip that bound.
  static Future<List<CompanyBusRoute>> buildCtbRoutes() async {
    final routes = await DataServices.getCtbRoutes();

    final ctbCompanyBusRoutes = <CompanyBusRoute>[];
    final total = routes.length * 2;
    final start = DateTime.now();
    int count = 0;

    await Future.wait(
      routes.expand(
        (e) => Bound.values.map((bound) async {
          final stops = await DataServices.getCtbRouteStops(
            e.route,
            bound.label,
          );

          if (stops.isNotEmpty) {
            final newRoute = CompanyBusRoute(
              company: Company.CTB,
              number: e.route,
              bound: bound,
              originEn: bound == Bound.O ? e.origEn : e.destEn,
              originChiT: bound == Bound.O ? e.origTc : e.destTc,
              destEn: bound == Bound.O ? e.destEn : e.origEn,
              destChiT: bound == Bound.O ? e.destTc : e.origTc,
              serviceType: null,
              nlbRouteId: null,
              stops: stops.map((s) => s.stopId).toList(),
            );
            ctbCompanyBusRoutes.add(newRoute);
          }
          count++;

          // Print progress
          if (count % 50 == 0 || count == total) {
            final elapsed =
                DateTime.now().difference(start).inMilliseconds / 1000;
            final percent = (count / total * 100).toStringAsFixed(1);
            stdout.write(
              '\rGetting CTB routes: $count/$total $percent% (${elapsed}s)',
            );
          }
        }),
      ),
    );
    return ctbCompanyBusRoutes;
  }

  static Future<List<CompanyBusRoute>> buildNlbRoutes() async {
    final routes = await DataServices.getNlbRoutes();

    // Sort by routeId (as int)
    routes.sortBy((r) => int.tryParse(r.routeId) ?? 0);

    final List<CompanyBusRoute> nlbCompanyBusRoutes = [];

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
    }
    return nlbCompanyBusRoutes;
  }

  static Future<List<CompanyBusRoute>> buildMtrbRoutes() async {
    final mtrbRouteMap = await MtrbParser.parseMtrbData(
      ProjectPaths.mtrbDataPath,
    );
    final List<CompanyBusRoute> mtrbCompanyBusRoutes = [];

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

    return mtrbCompanyBusRoutes;
  }
}
