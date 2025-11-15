import 'package:json_annotation/json_annotation.dart';

part '../generated/json/geometry.g.dart';

@JsonSerializable()
class Geometry {
  final List<double> coordinates;

  const Geometry({required this.coordinates});

  factory Geometry.fromJson(Map<String, dynamic> json) =>
      _$GeometryFromJson(json);

  Map<String, dynamic> toJson() => _$GeometryToJson(this);
}
