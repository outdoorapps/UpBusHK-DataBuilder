import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/isar/builder_models/gov_route_stop.dart';
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';
import 'package:up_bus_hk_data_builder/json/geometry.dart';

part '../generated/json/gov_route_stop_json.g.dart';

@JsonSerializable(explicitToJson: true)
class GovRouteStopJson {
  final Geometry geometry;
  final GovRouteStopProperties properties;

  const GovRouteStopJson({required this.geometry, required this.properties});

  factory GovRouteStopJson.fromJson(Map<String, dynamic> json) =>
      _$GovRouteStopJsonFromJson(json);

  Map<String, dynamic> toJson() => _$GovRouteStopJsonToJson(this);

  /// Convert JSON → Isar model
  GovRouteStop toGovRouteStop() {
    return GovRouteStop(
      routeId: properties.routeId,
      companyCode: properties.companyCode,

      // English route name preferred (same as your Kotlin logic)
      routeName: properties.routeNameE,

      routeType: properties.routeType,
      serviceMode: properties.serviceMode,
      specialType: properties.specialType,
      journeyTime: properties.journeyTime,

      locStartNameC: properties.locStartNameC,
      locStartNameE: properties.locStartNameE,
      locEndNameC: properties.locEndNameC,
      locEndNameE: properties.locEndNameE,

      fullFare: properties.fullFare,

      routeSeq: properties.routeSeq,
      stopSeq: properties.stopSeq,
      stopId: properties.stopId,

      stopNameC: properties.stopNameC,
      stopNameE: properties.stopNameE,

      latLng: LatLng(
        lat: geometry.coordinates[1],
        long: geometry.coordinates[0],
      ),
    );
  }
}

@JsonSerializable()
class GovRouteStopProperties {
  final int routeId;
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

  const GovRouteStopProperties({
    required this.routeId,
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

  factory GovRouteStopProperties.fromJson(Map<String, dynamic> json) =>
      _$GovRouteStopPropertiesFromJson(json);

  Map<String, dynamic> toJson() => _$GovRouteStopPropertiesToJson(this);
}
