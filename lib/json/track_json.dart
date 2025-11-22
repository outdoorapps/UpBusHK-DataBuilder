import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_data_builder/json/json_converters.dart';

part '../generated/json/track_json.g.dart';

@JsonSerializable(explicitToJson: true)
class TrackFeature {
  final String type;

  @TrackGeometryConverter()
  final TrackGeometry geometry;
  final TrackProperties properties;

  TrackFeature({
    required this.type,
    required this.geometry,
    required this.properties,
  });

  factory TrackFeature.fromJson(Map<String, dynamic> json) =>
      _$TrackFeatureFromJson(json);

  Map<String, dynamic> toJson() => _$TrackFeatureToJson(this);
}

@JsonSerializable()
class TrackGeometry {
  final String type;
  final List<List<List<double>>> coordinates;

  TrackGeometry({required this.type, required this.coordinates});

  factory TrackGeometry.fromJson(Map<String, dynamic> json) =>
      _$TrackGeometryFromJson(json);

  Map<String, dynamic> toJson() => _$TrackGeometryToJson(this);
}

@JsonSerializable()
class TrackProperties {
  @JsonKey(name: "OBJECTID")
  final int objectId;

  @JsonKey(name: "ROUTE_ID")
  final int routeId;

  @JsonKey(name: "ROUTE_SEQ")
  final int routeSeq;

  @JsonKey(name: "COMPANY_CODE")
  final String companyCode;

  @JsonKey(name: "ROUTE_NAMEE")
  final String routeNameE;

  @JsonKey(name: "ST_STOP_ID")
  final int startStopId;

  @JsonKey(name: "ST_STOP_NAMEE")
  final String startStopNameE;

  @JsonKey(name: "ST_STOP_NAMEC")
  final String startStopNameC;

  @JsonKey(name: "ST_STOP_NAMES")
  final String startStopNameS;

  @JsonKey(name: "ED_STOP_ID")
  final int endStopId;

  @JsonKey(name: "ED_STOP_NAMEE")
  final String endStopNameE;

  @JsonKey(name: "ED_STOP_NAMEC")
  final String endStopNameC;

  @JsonKey(name: "ED_STOP_NAMES")
  final String endStopNameS;

  @JsonKey(name: "Shape_Length")
  final double shapeLength;

  TrackProperties({
    required this.objectId,
    required this.routeId,
    required this.routeSeq,
    required this.companyCode,
    required this.routeNameE,
    required this.startStopId,
    required this.startStopNameE,
    required this.startStopNameC,
    required this.startStopNameS,
    required this.endStopId,
    required this.endStopNameE,
    required this.endStopNameC,
    required this.endStopNameS,
    required this.shapeLength,
  });

  factory TrackProperties.fromJson(Map<String, dynamic> json) =>
      _$TrackPropertiesFromJson(json);

  Map<String, dynamic> toJson() => _$TrackPropertiesToJson(this);

  String get key => [routeId, routeSeq].join('-');
}
