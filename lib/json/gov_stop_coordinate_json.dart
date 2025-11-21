import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_stop_coordinate.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_data_builder/json/geometry.dart';

part '../generated/json/gov_stop_coordinate_json.g.dart';

@JsonSerializable()
class GovStopCoordinateJson {
  final Geometry geometry;
  final StopBusProperties properties;

  GovStopCoordinateJson({required this.geometry, required this.properties});

  factory GovStopCoordinateJson.fromJson(Map<String, dynamic> json) =>
      _$GovStopCoordinateJsonFromJson(json);

  Map<String, dynamic> toJson() => _$GovStopCoordinateJsonToJson(this);

  GovStopCoordinate toGovStopCoordinate() => GovStopCoordinate(
    stopId: properties.stopId,
    latLng: LatLng(lat: geometry.coordinates[1], long: geometry.coordinates[0]),
  );
}

@JsonSerializable()
class StopBusProperties {
  @JsonKey(name: "OBJECTID")
  final int objectId;

  @JsonKey(name: "STOP_ID")
  final int stopId;

  @JsonKey(name: "LAST_UPDATE_DATE")
  final String lastUpdateDate; // keep raw "YYYYMMDD"

  StopBusProperties({
    required this.objectId,
    required this.stopId,
    required this.lastUpdateDate,
  });

  factory StopBusProperties.fromJson(Map<String, dynamic> json) =>
      _$StopBusPropertiesFromJson(json);

  Map<String, dynamic> toJson() => _$StopBusPropertiesToJson(this);
}
