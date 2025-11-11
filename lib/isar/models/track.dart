import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
part '../../generated/isar/models/track.g.dart';

@JsonSerializable()
@Collection()
class Track {
  @JsonKey(includeFromJson: false, includeToJson: false)
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  final int trackId;

  @JsonKey(name: 'coordinates')
  // @LatLngListConverter()
  final List<double> latLngs; //todo

  Track({required this.trackId, required this.latLngs});

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  Map<String, dynamic> toJson() => _$TrackToJson(this);
}
