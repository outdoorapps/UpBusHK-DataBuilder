import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/enums.dart';

part '../generated/json/kmb_route.g.dart';

/// KMB Route Response
@JsonSerializable(explicitToJson: true)
class KmbRouteResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final List<KmbRoute> data;

  KmbRouteResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.data,
  });

  factory KmbRouteResponse.fromJson(Map<String, dynamic> json) =>
      _$KmbRouteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KmbRouteResponseToJson(this);
}

/// KMB Route Model
@JsonSerializable()
class KmbRoute {
  final String route;
  final Bound bound;

  @JsonKey(name: 'service_type')
  final String serviceType;

  @JsonKey(name: 'orig_en')
  final String origEn;

  @JsonKey(name: 'orig_tc')
  final String origTc;

  @JsonKey(name: 'orig_sc')
  final String origSc;

  @JsonKey(name: 'dest_en')
  final String destEn;

  @JsonKey(name: 'dest_tc')
  final String destTc;

  @JsonKey(name: 'dest_sc')
  final String destSc;

  KmbRoute({
    required this.route,
    required this.bound,
    required this.serviceType,
    required this.origEn,
    required this.origTc,
    required this.origSc,
    required this.destEn,
    required this.destTc,
    required this.destSc,
  });

  factory KmbRoute.fromJson(Map<String, dynamic> json) =>
      _$KmbRouteFromJson(json);
  Map<String, dynamic> toJson() => _$KmbRouteToJson(this);

  String get key => "$route-${bound.label}-$serviceType";
}
