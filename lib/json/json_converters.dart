import 'package:json_annotation/json_annotation.dart';
import 'package:up_bus_hk_core/enums/region.dart';
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';
import 'package:up_bus_hk_data_builder/json/track_json.dart';

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

class Wgs84Converter implements JsonConverter<LatLng, Map<String, dynamic>> {
  const Wgs84Converter();

  @override
  LatLng fromJson(Map<String, dynamic> json) {
    return LatLng(
      lat: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      long: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  Map<String, dynamic> toJson(LatLng latLng) => {
    'latitude': latLng.lat,
    'longitude': latLng.long,
  };
}

class TrackGeometryConverter
    implements JsonConverter<TrackGeometry, Map<String, dynamic>> {
  const TrackGeometryConverter();

  @override
  TrackGeometry fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final raw = json['coordinates'] as List<dynamic>;

    if (type == 'LineString') {
      // Convert LineString → List<List<double>>
      final line = raw
          .map<List<double>>((p) => [p[0] as double, p[1] as double])
          .toList();

      return TrackGeometry(
        type: type,
        coordinates: [line], // Normalize into MultiLineString shape
      );
    }

    if (type == 'MultiLineString') {
      final multi = raw
          .map<List<List<double>>>(
            (line) => (line as List)
                .map<List<double>>((p) => [p[0] as double, p[1] as double])
                .toList(),
          )
          .toList();

      return TrackGeometry(type: type, coordinates: multi);
    }

    if (type == 'Point') {
      final p = raw;
      final point = [p[0] as double, p[1] as double];

      return TrackGeometry(
        type: type,
        coordinates: [
          [point],
        ],
      );
    }

    throw UnsupportedError('Unsupported geometry type: $type');
  }

  @override
  Map<String, dynamic> toJson(TrackGeometry geom) {
    return {'type': geom.type, 'coordinates': geom.coordinates};
  }
}
