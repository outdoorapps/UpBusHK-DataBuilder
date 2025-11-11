import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/transit_route.dart';

part '../../generated/isar/models/bus_route.g.dart';

@JsonSerializable(explicitToJson: true)
@Collection()
class BusRoute extends TransitRoute {
  @enumerated
  final List<Company> companies;

  @Enumerated(EnumType.ordinal32)
  final Bound? secondaryBound;

  final int? serviceType;
  final String? nlbRouteId;
  final int? trackId;
  final List<double?> fares;
  final List<String> secondaryStops;

  BusRoute({
    required this.companies,
    required super.number,
    required super.bound,
    required this.secondaryBound,
    required super.originEn,
    required super.originChiT,
    required super.originChiS,
    required super.destEn,
    required super.destChiT,
    required super.destChiS,
    this.serviceType,
    this.nlbRouteId,
    this.trackId,
    required super.fullFare,
    required super.stops,
    required this.secondaryStops,
    required this.fares,
  }) : super(
         routeId: _generateRouteId(
           companies: companies,
           number: number,
           bound: bound,
           serviceType: serviceType,
           nlbRouteId: nlbRouteId,
         ),
       );

  @override
  String toString() => '$companies,$number,$bound,$serviceType';

  /// Factory + serialization helpers
  factory BusRoute.fromJson(Map<String, dynamic> json) =>
      _$BusRouteFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$BusRouteToJson(this);

  /// Custom route ID generation
  static String _generateRouteId({
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
