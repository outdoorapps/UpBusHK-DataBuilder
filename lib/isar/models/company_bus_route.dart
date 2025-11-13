import 'package:isar_community/isar.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';

part '../../generated/isar/models/company_bus_route.g.dart';

@collection
class CompanyBusRoute {
  Id id = Isar.autoIncrement;

  @enumerated
  final Company company;

  /// Route number, e.g., "2", "102", "N118"
  @Index()
  final String number;

  @enumerated
  final Bound bound;

  final String originEn;
  final String originChiT;

  final String destEn;
  final String destChiT;

  /// For KMB/LWB, nullable for others
  final int? serviceType;

  /// For NLB routes (string routeId)
  final String? nlbRouteId;

  /// Related stop IDs (string identifiers, e.g. "001234")
  final List<String> stops;

  /// Optional: if you’ll later store route shape / track info
  final int? trackId;

  CompanyBusRoute({
    required this.company,
    required this.number,
    required this.bound,
    required this.originEn,
    required this.originChiT,
    required this.destEn,
    required this.destChiT,
    required this.serviceType,
    required this.nlbRouteId,
    required this.stops,
    this.trackId,
  });
}
