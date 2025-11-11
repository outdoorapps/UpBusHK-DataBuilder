import 'package:json_annotation/json_annotation.dart';

part '../generated/json/kmb_stop.g.dart';

/// KMB Stop Response
@JsonSerializable(explicitToJson: true)
class KmbStopResponse {
  final String type;
  final String version;

  @JsonKey(name: 'generated_timestamp')
  final String generatedTimestamp;

  final List<KmbStop> data;

  KmbStopResponse({
    required this.type,
    required this.version,
    required this.generatedTimestamp,
    required this.data,
  });

  factory KmbStopResponse.fromJson(Map<String, dynamic> json) =>
      _$KmbStopResponseFromJson(json);
  Map<String, dynamic> toJson() => _$KmbStopResponseToJson(this);
}

/// KMB Stop
@JsonSerializable()
class KmbStop {
  final String stop;

  @JsonKey(name: 'name_en')
  final String nameEn;

  @JsonKey(name: 'name_tc')
  final String nameTc;

  @JsonKey(name: 'name_sc')
  final String nameSc;

  final String lat;
  @JsonKey(name: 'long')
  final String lng; // renamed for clarity but still maps to "long"

  KmbStop({
    required this.stop,
    required this.nameEn,
    required this.nameTc,
    required this.nameSc,
    required this.lat,
    required this.lng,
  });

  factory KmbStop.fromJson(Map<String, dynamic> json) =>
      _$KmbStopFromJson(json);
  Map<String, dynamic> toJson() => _$KmbStopToJson(this);
}
