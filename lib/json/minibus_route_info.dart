import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/region.dart';

part '../generated/json/minibus_route_info.g.dart';

/// Minibus (GMB) Route Info Response
@JsonSerializable(explicitToJson: true)
class MinibusRouteOverviewResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  @JsonKey(name: 'data')
  final List<GovMinibusRoute> routes;

  MinibusRouteOverviewResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.routes,
  });

  factory MinibusRouteOverviewResponse.fromJson(Map<String, dynamic> json) =>
      _$MinibusRouteOverviewResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusRouteOverviewResponseToJson(this);
}

/// Route Info Entry
@JsonSerializable(explicitToJson: true)
class GovMinibusRoute {
  @JsonKey(name: 'route_id')
  final int routeId;

  final Region region;

  @JsonKey(name: 'route_code')
  final String routeCode;

  @JsonKey(name: 'description_tc')
  final String descriptionTc;

  @JsonKey(name: 'description_sc')
  final String descriptionSc;

  @JsonKey(name: 'description_en')
  final String descriptionEn;

  final List<MinibusDirection> directions;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  GovMinibusRoute({
    required this.routeId,
    required this.region,
    required this.routeCode,
    required this.descriptionTc,
    required this.descriptionSc,
    required this.descriptionEn,
    required this.directions,
    required this.dataTimestamp,
  });

  factory GovMinibusRoute.fromJson(Map<String, dynamic> json) =>
      _$GovMinibusRouteFromJson(json);

  Map<String, dynamic> toJson() => _$GovMinibusRouteToJson(this);
}

/// Route Direction Info
@JsonSerializable(explicitToJson: true)
class MinibusDirection {
  @JsonKey(name: 'route_seq')
  final int routeSeq;

  @JsonKey(name: 'orig_tc')
  final String origTc;

  @JsonKey(name: 'orig_sc')
  final String origSc;

  @JsonKey(name: 'orig_en')
  final String origEn;

  @JsonKey(name: 'dest_tc')
  final String destTc;

  @JsonKey(name: 'dest_sc')
  final String destSc;

  @JsonKey(name: 'dest_en')
  final String destEn;

  @JsonKey(name: 'remarks_tc')
  final String? remarksTc;

  @JsonKey(name: 'remarks_sc')
  final String? remarksSc;

  @JsonKey(name: 'remarks_en')
  final String? remarksEn;

  final List<Headway> headways;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  MinibusDirection({
    required this.routeSeq,
    required this.origTc,
    required this.origSc,
    required this.origEn,
    required this.destTc,
    required this.destSc,
    required this.destEn,
    this.remarksTc,
    this.remarksSc,
    this.remarksEn,
    required this.headways,
    required this.dataTimestamp,
  });

  factory MinibusDirection.fromJson(Map<String, dynamic> json) =>
      _$MinibusDirectionFromJson(json);

  Map<String, dynamic> toJson() => _$MinibusDirectionToJson(this);

  Bound get bound => routeSeq == 1 ? Bound.O : Bound.I;
}

/// Headway info (minibus route frequency data)
@JsonSerializable()
class Headway {
  final List<bool> weekdays;

  @JsonKey(name: 'public_holiday')
  final bool publicHoliday;

  @JsonKey(name: 'headway_seq')
  final int headwaySeq;

  @JsonKey(name: 'start_time')
  final String startTime;

  @JsonKey(name: 'end_time')
  final String endTime;

  final int? frequency;

  @JsonKey(name: 'frequency_upper')
  final dynamic frequencyUpper; // can be int, string, or null

  Headway({
    required this.weekdays,
    required this.publicHoliday,
    required this.headwaySeq,
    required this.startTime,
    required this.endTime,
    this.frequency,
    this.frequencyUpper,
  });

  factory Headway.fromJson(Map<String, dynamic> json) =>
      _$HeadwayFromJson(json);

  Map<String, dynamic> toJson() => _$HeadwayToJson(this);
}
