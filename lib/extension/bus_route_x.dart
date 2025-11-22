import 'package:up_bus_hk_core/isar/models/transit_route.dart';

extension BusRouteX on BusRoute {
  String get fareGroupKey {
    final parts = routeId.split('-');
    final companyCode = parts[0];
    return [companyCode, number, bound.name].join('-');
  }
}
