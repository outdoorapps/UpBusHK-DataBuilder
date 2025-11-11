import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/json/json_converters.dart';

part '../generated/json/minibus_route_by_region.g.dart';

@JsonSerializable()
class MinibusRouteByRegionResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final MinibusRouteRegionData data;

  MinibusRouteByRegionResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.data,
  });

  factory MinibusRouteByRegionResponse.fromJson(Map<String, dynamic> json) =>
      _$MinibusRouteByRegionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusRouteByRegionResponseToJson(this);
}

@JsonSerializable()
class MinibusRouteRegionData {
  @JsonKey(name: 'routes')
  @RegionMapConverter()
  final Map<Region, List<String>> routesByRegion;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  MinibusRouteRegionData({
    required this.routesByRegion,
    required this.dataTimestamp,
  });

  factory MinibusRouteRegionData.fromJson(Map<String, dynamic> json) =>
      _$MinibusRouteRegionDataFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusRouteRegionDataToJson(this);
}

