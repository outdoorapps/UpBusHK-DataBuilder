import 'package:json_annotation/json_annotation.dart';

part '../generated/json/minibus_route_stop.g.dart';

/// Minibus (GMB) Route–Stop Response
@JsonSerializable(explicitToJson: true)
class MinibusRouteStopResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final MinibusRouteStopData data;

  MinibusRouteStopResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.data,
  });

  factory MinibusRouteStopResponse.fromJson(Map<String, dynamic> json) =>
      _$MinibusRouteStopResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MinibusRouteStopResponseToJson(this);
}

/// Wrapper for route-stop list and timestamp
@JsonSerializable(explicitToJson: true)
class MinibusRouteStopData {
  @JsonKey(name: 'route_stops')
  final List<RouteStop> routeStops;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  MinibusRouteStopData({
    required this.routeStops,
    required this.dataTimestamp,
  });

  factory MinibusRouteStopData.fromJson(Map<String, dynamic> json) =>
      _$MinibusRouteStopDataFromJson(json);
  Map<String, dynamic> toJson() => _$MinibusRouteStopDataToJson(this);
}

/// Individual route-stop entry
@JsonSerializable()
class RouteStop {
  @JsonKey(name: 'stop_seq')
  final int stopSeq;

  @JsonKey(name: 'stop_id')
  final int stopID;

  @JsonKey(name: 'name_tc')
  final String nameTc;

  @JsonKey(name: 'name_sc')
  final String nameSc;

  @JsonKey(name: 'name_en')
  final String nameEn;

  RouteStop({
    required this.stopSeq,
    required this.stopID,
    required this.nameTc,
    required this.nameSc,
    required this.nameEn,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) =>
      _$RouteStopFromJson(json);
  Map<String, dynamic> toJson() => _$RouteStopToJson(this);
}
