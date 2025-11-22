import 'package:json_annotation/json_annotation.dart';

part '../generated/json/nlb_route_stop.g.dart';

/// NLB Route–Stop Response
@JsonSerializable(explicitToJson: true)
class NlbRouteStopResponse {
  final List<NlbStop> stops;

  NlbRouteStopResponse({required this.stops});

  factory NlbRouteStopResponse.fromJson(Map<String, dynamic> json) =>
      _$NlbRouteStopResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NlbRouteStopResponseToJson(this);
}

/// NLB Stop (per route)
@JsonSerializable()
class NlbStop {
  final String stopId;

  @JsonKey(name: 'stopName_c')
  final String stopNameC;

  @JsonKey(name: 'stopName_s')
  final String stopNameS;

  @JsonKey(name: 'stopName_e')
  final String stopNameE;

  @JsonKey(name: 'stopLocation_c')
  final String stopLocationC;

  @JsonKey(name: 'stopLocation_s')
  final String stopLocationS;

  @JsonKey(name: 'stopLocation_e')
  final String stopLocationE;

  final String latitude;
  final String longitude;
  final String fare;
  final String fareHoliday;
  final int someDepartureObserveOnly;

  NlbStop({
    required this.stopId,
    required this.stopNameC,
    required this.stopNameS,
    required this.stopNameE,
    required this.stopLocationC,
    required this.stopLocationS,
    required this.stopLocationE,
    required this.latitude,
    required this.longitude,
    required this.fare,
    required this.fareHoliday,
    required this.someDepartureObserveOnly,
  });

  factory NlbStop.fromJson(Map<String, dynamic> json) =>
      _$NlbStopFromJson(json);

  Map<String, dynamic> toJson() => _$NlbStopToJson(this);
}
