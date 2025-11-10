import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/enums.dart';

part '../generated/json/bus_route.g.dart';

@JsonSerializable()
class BusRoute {
  final Set<Company> companies;
  final String number;
  final Bound bound;
  final Bound? secondaryBound;
  final String originEn;
  final String originChiT;
  final String originChiS;
  final String destEn;
  final String destChiT;
  final String destChiS;
  final int? serviceType;
  final String? nlbRouteId;
  final int? trackId;
  final double? fullFare;
  final List<String> stops;
  final List<String> secondaryStops;
  final List<double?> fares;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<MapEntry<String, double?>>? stopFarePairs;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? govRouteId;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? govRouteSeq;

  BusRoute({
    required this.companies,
    required this.number,
    required this.bound,
    this.secondaryBound,
    required this.originEn,
    required this.originChiT,
    required this.originChiS,
    required this.destEn,
    required this.destChiT,
    required this.destChiS,
    this.serviceType,
    this.nlbRouteId,
    this.trackId,
    this.fullFare,
    required this.stops,
    required this.secondaryStops,
    required this.fares,
    this.stopFarePairs,
    this.govRouteId,
    this.govRouteSeq,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) =>
      _$BusRouteFromJson(json);

  Map<String, dynamic> toJson() => _$BusRouteToJson(this);
}
