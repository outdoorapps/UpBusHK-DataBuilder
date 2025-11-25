import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_data_builder/json/json_converters.dart';

part '../generated/json/ctb_stop.g.dart';

/// Citybus (CTB) Stop Response
@JsonSerializable(explicitToJson: true)
class CtbStopResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  @CtbStopConverter()
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
  final String stop;

  @JsonKey(name: 'name_tc')
  final String nameTc;

  @JsonKey(name: 'name_en')
  final String nameEn;

  final String lat;

  final String long;

  @JsonKey(name: 'name_sc')
  final String nameSc;

  @JsonKey(name: 'data_timestamp')
  final String dataTimestamp;

  CtbStop({
    required this.stop,
    required this.nameTc,
    required this.nameEn,
    required this.lat,
    required this.long,
    required this.nameSc,
    required this.dataTimestamp,
  });

  factory CtbStop.fromJson(Map<String, dynamic> json) =>
      _$CtbStopFromJson(json);

  factory CtbStop.empty(String stopId) => CtbStop(
    stop: stopId,
    nameTc: '',
    nameEn: '',
    lat: '',
    long: '',
    nameSc: '',
    dataTimestamp: '',
  );

  Map<String, dynamic> toJson() => _$CtbStopToJson(this);
}
