import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_route.dart';
import 'package:up_bus_hk_data_builder/builders/gov_bus_builder.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';

class BusRouteBuilder {
  static const double routeInfoErrorDistanceMeters = 220.0; // 38X cap
  static const double jointRouteErrorDistanceMeters = 160.0;
  static const double circularRouteErrorDistanceMeters = 250.0; // CTB 25 cap
  static const double stopMatchErrorDistanceMeters = 50.0;

  static Future<List<BusRoute>> build() async {
    // await GovBusBuilder.build(); //todo
    final routes = <BusRoute>[];

    final jointGovRoutes = await builderIsar.govBusRoutes
        .filter()
        .companyCodeContains('+')
        .findAll();
    final jointRouteNumbers = jointGovRoutes.map((e) => e.routeNameE).toSet();

    final lwbGovRoutes = await builderIsar.govBusRoutes
        .filter()
        .companyCodeContains('LWB')
        .findAll();
    final lwbRouteNumbers = lwbGovRoutes.map((e) => e.routeNameE).toSet();

    final kmbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.KMB)
        .findAll();

    final ctbCompanyRoutes = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.CTB)
        .findAll();

    kmbCompanyRoutes.forEach((e) {
      final isJoint = jointRouteNumbers.contains(e.number);
      if (isJoint) {
      } else {
        final isLwb = lwbRouteNumbers.contains(e.number);
        // BusRoute(
        //   routeId: '', //todo generate
        //   companies: [isLwb ? Company.LWB : Company.KMB], //todo LWB
        //   number: e.number,
        //   bound: e.bound,
        //   secondaryBound: null,
        //
        // );
      }
    });

    final g = await builderIsar.govBusRoutes
        .where()
        .distinctByCompanyCode()
        .findAll();

    g.forEach((e) => print(e.companyCode));

    // 1. Create joint route pairs
    jointGovRoutes.forEach((e) {});

    return [];
  }
}
