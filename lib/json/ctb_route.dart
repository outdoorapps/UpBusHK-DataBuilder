import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/enums/bound.dart';

part '../generated/json/ctb_route.g.dart';

/// Citybus (CTB) Route Response
@JsonSerializable(explicitToJson: true)
class CtbRouteResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final List<CtbRoute> data;

  CtbRouteResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.data,
  });

  factory CtbRouteResponse.fromJson(Map<String, dynamic> json) =>
      _$CtbRouteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CtbRouteResponseToJson(this);
}

/// Citybus (CTB) Route
@JsonSerializable()
class CtbRoute {
  final String co;
  final String route;

  @JsonKey(name: 'orig_tc')
  final String origTc;

  @JsonKey(name: 'orig_en')
  final String origEn;

  @JsonKey(name: 'dest_tc')
  final String destTc;

  @JsonKey(name: 'dest_en')
  final String destEn;

  @JsonKey(name: 'orig_sc')
  final String origSc;

  @JsonKey(name: 'dest_sc')
  final String destSc;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  CtbRoute({
    required this.co,
    required this.route,
    required this.origTc,
    required this.origEn,
    required this.destTc,
    required this.destEn,
    required this.origSc,
    required this.destSc,
    required this.dataTimestamp,
  });

  factory CtbRoute.fromJson(Map<String, dynamic> json) =>
      _$CtbRouteFromJson(json);
  Map<String, dynamic> toJson() => _$CtbRouteToJson(this);

  String key(Bound bound) => "$route-${bound.label}";
}
