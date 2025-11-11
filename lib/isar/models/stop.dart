import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/json/json_converters.dart';
abstract class Stop {
  @JsonKey(includeToJson: false, includeFromJson: false)
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String stopId;
  final String engName;
  final String chiTName;
  final String chiSName;

  @LatLngConverter()
  final LatLng coordinate;

  Stop({
    required this.stopId,
    required this.engName,
    required this.chiTName,
    required this.chiSName,
    required this.coordinate,
  });

  Map<String, dynamic> toJson();

  @override
  String toString() => stopId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Stop && stopId == other.stopId;

  @override
  int get hashCode => hash(stopId);

  // String getName(SupportedLanguage language) => switch (language) {
  //   SupportedLanguage.zh_Hant => chiTName,
  //   SupportedLanguage.zh_Hans => chiSName,
  //   SupportedLanguage.en => engName,
  // };
}
