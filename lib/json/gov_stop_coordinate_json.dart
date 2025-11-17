import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_data_builder/isar/gov_stop_coordinate.dart';
import 'package:up_bus_hk_data_builder/json/geometry.dart';
import 'package:up_bus_hk_data_builder/utils/crs_2326.dart';

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
    latLng: Crs2326.convert(geometry.coordinates[0], geometry.coordinates[1]),
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
