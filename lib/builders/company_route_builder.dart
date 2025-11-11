import 'dart:io';

import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/company_bus_route.dart';
import 'package:upbushk_data_builder/network/data_services.dart';

class CompanyRouteBuilder {
  static Future<List<CompanyBusRoute>> buildKmbRoutes() async {
    final kmbRoutes = await DataServices.getKmbRoutes();
    return await Future.wait(
      kmbRoutes.map((e) async {
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
          originChiS: e.origSc,
          destEn: e.destEn,
          destChiT: e.destTc,
          destChiS: e.destSc,
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
              originEn: bound == Bound.outbound ? e.origEn : e.destEn,
              originChiT: bound == Bound.outbound ? e.origTc : e.destTc,
              originChiS: bound == Bound.outbound ? e.origSc : e.destSc,
              destEn: bound == Bound.outbound ? e.destEn : e.origEn,
              destChiT: bound == Bound.outbound ? e.destTc : e.origTc,
              destChiS: bound == Bound.outbound ? e.destSc : e.origSc,
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

  // Future<List<CompanyBusRoute>> getNlbRoutes() async {
  //   final routes = await DataServices.getNlbRoutes();
  //   return await Future.wait();
  // }
}
