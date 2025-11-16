import 'package:up_bus_hk_core/isar/models/bus_route.dart';
import 'package:up_bus_hk_data_builder/builders/bus_fare_parser.dart';
import 'package:up_bus_hk_data_builder/builders/gov_bus_parser.dart';

class BusRouteBuilder {
  static const double routeInfoErrorDistanceMeters = 220.0; // 38X cap
  static const double jointRouteErrorDistanceMeters = 160.0;
  static const double circularRouteErrorDistanceMeters = 250.0; // CTB 25 cap
  static const double stopMatchErrorDistanceMeters = 50.0;

  Future<List<BusRoute>> build() async {
    await BusFareParser().parseBusFareData();

    // await GovBusParser().parseRouteStops();


    return [];
  }
}
