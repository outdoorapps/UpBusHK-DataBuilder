import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/enums/bound.dart';

part '../generated/json/kmb_route_stop.g.dart';

/// KMB Route Stop Response
@JsonSerializable(explicitToJson: true)
class KmbRouteStopResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  @JsonKey(name: 'data')
  final List<KmbRouteStop> stops;

  KmbRouteStopResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.stops,
  });

  factory KmbRouteStopResponse.fromJson(Map<String, dynamic> json) =>
      _$KmbRouteStopResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KmbRouteStopResponseToJson(this);
}

/// KMB Route Stop mapping
@JsonSerializable()
class KmbRouteStop {
  final String route;
  final Bound bound;

  @JsonKey(name: 'service_type')
  final String serviceType;

  final String seq;

  @JsonKey(name: 'stop')
  final String stopId;

  KmbRouteStop({
    required this.route,
    required this.bound,
    required this.serviceType,
    required this.seq,
    required this.stopId,
  });

  factory KmbRouteStop.fromJson(Map<String, dynamic> json) =>
      _$KmbRouteStopFromJson(json);
  Map<String, dynamic> toJson() => _$KmbRouteStopToJson(this);
}
