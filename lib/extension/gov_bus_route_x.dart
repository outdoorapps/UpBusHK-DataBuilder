import 'package:up_bus_hk_core/isar/builder_models/gov_bus_route.dart';

extension GovBusRouteX on GovBusRoute {
  bool get isJointRoute => companyCode.contains('+');
}
