import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part '../../generated/isar/models/lat_lng.g.dart';

@JsonSerializable()
@Embedded()
class LatLng {
  final double lat;
  final double long;

  /// Always round to 5 decimal places
  LatLng({double lat = 0, double long = 0}) : lat = _r(lat), long = _r(long);

  factory LatLng.fromList(List<dynamic> list) =>
      LatLng(lat: list[0] as double, long: list[1] as double);

  factory LatLng.fromJson(Map<String, dynamic> json) => _$LatLngFromJson(json);

  Map<String, dynamic> toJson() => _$LatLngToJson(this);

  bool isEqual(LatLng latLng) => lat == latLng.lat && long == latLng.long;

  bool isValid() => lat != 0 && long != 0;

  /// Round to 5 decimal places
  static double _r(double v) {
    const scale = 1e5;
    return (v * scale).round() / scale;
  }
}
