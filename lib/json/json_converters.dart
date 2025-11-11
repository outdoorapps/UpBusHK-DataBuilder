import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';

class LatLngConverter implements JsonConverter<LatLng, dynamic> {
  const LatLngConverter();

  @override
  LatLng fromJson(dynamic json) {
    if (json is List && json.length >= 2) {
      return LatLng.fromList(json);
    }
    throw ArgumentError('Invalid LatLng format: $json');
  }

  @override
  dynamic toJson(LatLng object) => [object.lat, object.long];
}