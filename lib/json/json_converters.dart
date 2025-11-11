import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
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

/// Converts between Map<String, List<String>> and Map<Region, List<String>>
class RegionMapConverter
    implements JsonConverter<Map<Region, List<String>>, Map<String, dynamic>> {
  const RegionMapConverter();

  @override
  Map<Region, List<String>> fromJson(Map<String, dynamic> json) {
    return json.map((key, value) {
      final region = Region.values.firstWhere(
        (e) => e.name.toUpperCase() == key.toUpperCase(),
        orElse: () => Region.HKI, // fallback
      );
      return MapEntry(region, List<String>.from(value));
    });
  }

  @override
  Map<String, dynamic> toJson(Map<Region, List<String>> object) =>
      object.map((key, value) => MapEntry(key.name, value));
}
