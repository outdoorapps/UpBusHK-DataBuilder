import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_data_builder/json/json_converters.dart';

part '../generated/json/minibus_stop.g.dart';

/// Minibus (GMB) Stop Response
@JsonSerializable(explicitToJson: true)
class MinibusStopResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final MinibusStopData data;

  MinibusStopResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.data,
  });

  factory MinibusStopResponse.fromJson(Map<String, dynamic> json) =>
      _$MinibusStopResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusStopResponseToJson(this);
}

/// Detailed Minibus Stop Info
@JsonSerializable(explicitToJson: true)
class MinibusStopData {
  final Coordinates coordinates;
  final bool enabled;

  @JsonKey(name: 'remarks_tc')
  final String? remarksTc;

  @JsonKey(name: 'remarks_sc')
  final String? remarksSc;

  @JsonKey(name: 'remarks_en')
  final String? remarksEn;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  MinibusStopData({
    required this.coordinates,
    required this.enabled,
    this.remarksTc,
    this.remarksSc,
    this.remarksEn,
    required this.dataTimestamp,
  });

  factory MinibusStopData.fromJson(Map<String, dynamic> json) =>
      _$MinibusStopDataFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusStopDataToJson(this);
}

/// Coordinate container (HK80 + WGS84)
@JsonSerializable(explicitToJson: true)
class Coordinates {
  @Wgs84Converter()
  final LatLng wgs84;
  final Coordinate hk80;

  Coordinates({required this.wgs84, required this.hk80});

  factory Coordinates.fromJson(Map<String, dynamic> json) =>
      _$CoordinatesFromJson(json);

  Map<String, dynamic> toJson() => _$CoordinatesToJson(this);
}

/// Coordinate system data (latitude, longitude)
@JsonSerializable()
class Coordinate {
  final double latitude;
  final double longitude;

  Coordinate({required this.latitude, required this.longitude});

  factory Coordinate.fromJson(Map<String, dynamic> json) =>
      _$CoordinateFromJson(json);

  Map<String, dynamic> toJson() => _$CoordinateToJson(this);
}
