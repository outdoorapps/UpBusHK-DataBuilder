import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_core/isar/models/minibus_stop.dart';
import 'package:up_bus_hk_core/isar/models/transit_route.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';

class Validator {
  static Future<bool> validate() async {
    final companyBusRoutes = await builderIsar.companyBusRoutes
        .where()
        .findAll();
    final busRoutes = await isar.busRoutes.where().findAll();
    final busStops = await isar.busStops.where().findAll();
    final minibusRoutes = await isar.minibusRoutes.where().findAll();
    final minibusStops = await isar.minibusStops.where().findAll();

    final expectedBusStopIds = <String>{};
    final expectedMinibusStopIds = <String>{};

    final missingRoutes = <CompanyBusRoute>{};
    final missingBusStops = <String>{};
    final missingMinibusRoutes = <String>{};
    final missingMinibusStops = <String>{};

    // Check if all CompanyBusRoutes have been transformed to BusRoutes
    companyBusRoutes.forEach((r) {
      if (busRoutes.none((b) => _routeMatch(r, b))) missingRoutes.add(r);
      expectedBusStopIds.addAll(r.stops);
    });

    // Check if all bus stops have been included
    expectedBusStopIds.forEach((id) {
      if (busStops.none((b) => b.stopId == id)) missingBusStops.add(id);
    });

    // Check for empty BusStops
    final emptyBusStops = busStops
        .where((s) => s.nameE.isEmpty || s.nameE.isEmpty || !s.latLng.isValid())
        .map((s) => s.stopId)
        .toList();

    // Check if all minibus routes have been included
    final response = await WebServices.minibus.getRoutesByRegion();
    response.data.routesByRegion.forEach((region, numbers) {
      if (minibusRoutes.none(
        (r) => r.region == region && r.number == numbers,
      )) {
        missingMinibusRoutes.add('$region-$numbers');
      }
    });

    // Check if all minibus stops have been included
    minibusRoutes.forEach((r) => expectedMinibusStopIds.addAll(r.stops));
    expectedMinibusStopIds.forEach((id) {
      if (minibusStops.none((s) => s.stopId == id)) missingMinibusStops.add(id);
    });

    // Check for empty MinibusStops
    final emptyMinibusStops = minibusStops
        .where((s) => s.nameE.isEmpty || s.nameE.isEmpty || !s.latLng.isValid())
        .map((s) => s.stopId)
        .toList();

    if (missingRoutes.isNotEmpty) print('Missing routes: $missingRoutes');
    if (missingBusStops.isNotEmpty)
      print('Missing bus stops: $missingBusStops');
    if (emptyBusStops.isNotEmpty) print('Invalid bus stops: $emptyBusStops');
    if (missingMinibusRoutes.isNotEmpty)
      print('Missing minibus routes: $missingMinibusRoutes');
    if (missingMinibusStops.isNotEmpty)
      print('Missing minibus stops: $missingMinibusStops');
    if (emptyMinibusStops.isNotEmpty)
      print('Invalid minibus stops: $emptyMinibusStops');

    return missingRoutes.isEmpty &&
        missingBusStops.isEmpty &&
        emptyBusStops.isEmpty &&
        missingMinibusRoutes.isEmpty &&
        missingMinibusStops.isEmpty &&
        emptyMinibusStops.isEmpty;
  }

  static bool _routeMatch(CompanyBusRoute companyBusRoute, BusRoute busRoute) {
    final companyMatches = companyBusRoute.company == Company.KMB
        ? busRoute.companies.contains(Company.KMB) ||
              busRoute.companies.contains(Company.LWB)
        : busRoute.companies.contains(companyBusRoute.company);

    final numberMatches = companyBusRoute.number == busRoute.number;
    final serviceTypeMatches = companyBusRoute.company == Company.KMB
        ? companyBusRoute.serviceType == busRoute.serviceType
        : true;

    final nlbRouteIdMatches = companyBusRoute.company == Company.NLB
        ? companyBusRoute.number == busRoute.nlbRouteId
        : true;

    return companyMatches &&
        numberMatches &&
        serviceTypeMatches &&
        nlbRouteIdMatches;
  }
}
