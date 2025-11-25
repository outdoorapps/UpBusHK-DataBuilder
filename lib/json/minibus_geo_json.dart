import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/enums/region.dart';
import 'package:up_bus_hk_data_builder/json/json_converters.dart';

part '../generated/json/minibus_geo_json.g.dart';

@JsonSerializable()
class MinibusGeoJson {
  final String type;
  final List<MinibusFeature> features;

  MinibusGeoJson({required this.type, required this.features});

  factory MinibusGeoJson.fromJson(Map<String, dynamic> json) =>
      _$MinibusGeoJsonFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusGeoJsonToJson(this);
}

@JsonSerializable()
class MinibusFeature {
  final String type;
  final MinibusGeometry geometry;
  final MinibusProperties properties;

  MinibusFeature({
    required this.type,
    required this.geometry,
    required this.properties,
  });

  factory MinibusFeature.fromJson(Map<String, dynamic> json) =>
      _$MinibusFeatureFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusFeatureToJson(this);
}

@JsonSerializable()
class MinibusGeometry {
  final String type;

  @LatLngConverter()
  @JsonKey(name: 'coordinates')
  final List<double> longLat;

  MinibusGeometry({required this.type, required this.longLat});

  factory MinibusGeometry.fromJson(Map<String, dynamic> json) =>
      _$MinibusGeometryFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusGeometryToJson(this);
}

@JsonSerializable()
class MinibusProperties {
  @JsonKey(name: 'routeId')
  final int govRouteId;
  final String companyCode;
  final String district;
  final String routeNameC;
  final String routeNameS;
  final String routeNameE;
  final int routeType;
  final String serviceMode;
  final int specialType;
  final int journeyTime;

  final String locStartNameC;
  final String locStartNameS;
  final String locStartNameE;
  final String locEndNameC;
  final String locEndNameS;
  final String locEndNameE;

  final String hyperlinkC;
  final String hyperlinkS;
  final String hyperlinkE;

  final double fullFare;
  final String lastUpdateDate;
  final int routeSeq;
  final int stopSeq;
  final int stopId;
  final int stopPickDrop;

  final String stopNameC;
  final String stopNameS;
  final String stopNameE;

  MinibusProperties({
    required this.govRouteId,
    required this.companyCode,
    required this.district,
    required this.routeNameC,
    required this.routeNameS,
    required this.routeNameE,
    required this.routeType,
    required this.serviceMode,
    required this.specialType,
    required this.journeyTime,
    required this.locStartNameC,
    required this.locStartNameS,
    required this.locStartNameE,
    required this.locEndNameC,
    required this.locEndNameS,
    required this.locEndNameE,
    required this.hyperlinkC,
    required this.hyperlinkS,
    required this.hyperlinkE,
    required this.fullFare,
    required this.lastUpdateDate,
    required this.routeSeq,
    required this.stopSeq,
    required this.stopId,
    required this.stopPickDrop,
    required this.stopNameC,
    required this.stopNameS,
    required this.stopNameE,
  });

  factory MinibusProperties.fromJson(Map<String, dynamic> json) =>
      _$MinibusPropertiesFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusPropertiesToJson(this);

  /// Convenience helpers
  Region get region => Region.values.byName(district);
}
