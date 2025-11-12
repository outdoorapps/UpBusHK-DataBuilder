import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part '../../generated/isar/models/lat_lng.g.dart';

@JsonSerializable()
@Embedded()
class LatLng {
  final double lat;
  final double long;

  const LatLng({this.lat = 0, this.long = 0});

  factory LatLng.fromList(List<dynamic> list) =>
      LatLng(lat: list[0] as double, long: list[1] as double);

  factory LatLng.fromWgs84(Map<String, dynamic> json) {
    return LatLng(
      lat: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      long: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory LatLng.fromJson(Map<String, dynamic> json) => _$LatLngFromJson(json);

  Map<String, dynamic> toJson() => _$LatLngToJson(this);

  bool isEqual(LatLng latLng) => lat == latLng.lat && long == latLng.long;

  bool isValid() => lat != 0 && long != 0;
}
