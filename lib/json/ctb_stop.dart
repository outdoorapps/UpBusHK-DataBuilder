import 'package:json_annotation/json_annotation.dart';

part '../generated/json/ctb_stop.g.dart';

/// Citybus (CTB) Stop Response
@JsonSerializable(explicitToJson: true)
class CtbStopResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final CtbStop? data;

  CtbStopResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    this.data,
  });

  factory CtbStopResponse.fromJson(Map<String, dynamic> json) =>
      _$CtbStopResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CtbStopResponseToJson(this);
}

/// Citybus (CTB) Stop
@JsonSerializable()
class CtbStop {
  final String? stop;

  @JsonKey(name: 'name_tc')
  final String? nameTc;

  @JsonKey(name: 'name_en')
  final String? nameEn;

  final String? lat;

  @JsonKey(name: 'long')
  final String? lng; // renamed for clarity; maps to JSON "long"

  @JsonKey(name: 'name_sc')
  final String? nameSc;

  @JsonKey(name: 'data_timestamp')
  final String? dataTimestamp;

  CtbStop({
    this.stop,
    this.nameTc,
    this.nameEn,
    this.lat,
    this.lng,
    this.nameSc,
    this.dataTimestamp,
  });

  factory CtbStop.fromJson(Map<String, dynamic> json) =>
      _$CtbStopFromJson(json);
  Map<String, dynamic> toJson() => _$CtbStopToJson(this);
}
