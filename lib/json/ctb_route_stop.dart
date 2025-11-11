import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';

part '../generated/json/ctb_route_stop.g.dart';

/// Citybus (CTB) Route–Stop Response
@JsonSerializable(explicitToJson: true)
class CtbRouteStopResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  @JsonKey(name: 'data')
  final List<CtbRouteStop> stops;

  CtbRouteStopResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.stops,
  });

  factory CtbRouteStopResponse.fromJson(Map<String, dynamic> json) =>
      _$CtbRouteStopResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CtbRouteStopResponseToJson(this);
}

/// Citybus (CTB) Route–Stop record
@JsonSerializable()
class CtbRouteStop {
  @JsonKey(name: 'co')
  final Company company;
  final String route;
  final Bound dir;
  final int seq;
  @JsonKey(name: 'stop')
  final String stopId;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  CtbRouteStop({
    required this.company,
    required this.route,
    required this.dir,
    required this.seq,
    required this.stopId,
    required this.dataTimestamp,
  });

  factory CtbRouteStop.fromJson(Map<String, dynamic> json) =>
      _$CtbRouteStopFromJson(json);

  Map<String, dynamic> toJson() => _$CtbRouteStopToJson(this);
}
