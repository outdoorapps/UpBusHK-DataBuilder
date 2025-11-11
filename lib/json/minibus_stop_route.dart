import 'package:json_annotation/json_annotation.dart';

part '../generated/json/minibus_stop_route.g.dart';

/// Minibus (GMB) Stop–Route Response
@JsonSerializable(explicitToJson: true)
class MinibusStopRouteResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final List<MinibusStopRouteData> data;

  MinibusStopRouteResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.data,
  });

  factory MinibusStopRouteResponse.fromJson(Map<String, dynamic> json) =>
      _$MinibusStopRouteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MinibusStopRouteResponseToJson(this);
}

/// Relationship between a Stop and its Route(s)
@JsonSerializable()
class MinibusStopRouteData {
  @JsonKey(name: 'route_id')
  final int routeID;

  @JsonKey(name: 'route_seq')
  final int routeSeq;

  @JsonKey(name: 'stop_seq')
  final int stopSeq;

  @JsonKey(name: 'name_tc')
  final String nameTc;

  @JsonKey(name: 'name_sc')
  final String nameSc;

  @JsonKey(name: 'name_en')
  final String nameEn;

  MinibusStopRouteData({
    required this.routeID,
    required this.routeSeq,
    required this.stopSeq,
    required this.nameTc,
    required this.nameSc,
    required this.nameEn,
  });

  factory MinibusStopRouteData.fromJson(Map<String, dynamic> json) =>
      _$MinibusStopRouteDataFromJson(json);
  Map<String, dynamic> toJson() => _$MinibusStopRouteDataToJson(this);
}
