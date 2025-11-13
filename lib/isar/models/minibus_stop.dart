import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/isar/models/stop.dart';
import 'package:upbushk_data_builder/json/json_converters.dart';

import 'lat_lng.dart';

part '../../generated/isar/models/minibus_stop.g.dart';

@JsonSerializable(explicitToJson: true)
@Collection()
@CopyWith()
class MinibusStop extends Stop {
  MinibusStop({
    required super.stopId,
    required super.engName,
    required super.chiTName,
    required super.chiSName,
    required super.latLng,
  });

  factory MinibusStop.fromJson(Map<String, dynamic> json) =>
      _$MinibusStopFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MinibusStopToJson(this);

  @override
  String toString() => stopId;
}
