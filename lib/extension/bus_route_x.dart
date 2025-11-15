import 'package:collection/collection.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/models/bus_route.dart';

extension BusRouteX on BusRoute {
  String generateRouteId({
    required List<Company> companies,
    required String number,
    required Bound bound,
    int? serviceType,
    String? nlbRouteId,
  }) {
    // Deterministic company ordering for consistent IDs
    final sortedCompanies = companies.map((e) => e.name).sorted();
    final companyCode = sortedCompanies.join(':');
    final serviceTypeText = serviceType != null ? '$serviceType' : '';
    final routeId = companies.contains(Company.NLB) ? nlbRouteId ?? '' : '';
    final parts = [
      companyCode,
      number,
      bound.name,
      serviceTypeText,
      routeId,
    ].where((e) => e.isNotEmpty);
    return parts.join('-');
  }
}
