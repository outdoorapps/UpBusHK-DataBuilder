import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/isar/models/stop.dart';
import 'package:upbushk_data_builder/json/json_converters.dart';

part '../../generated/isar/models/bus_stop.g.dart';

@JsonSerializable(explicitToJson: true)
@Collection()
class BusStop extends Stop {
  @enumerated
  final Company company;

  BusStop({
    required this.company,
    required super.stopId,
    required super.engName,
    required super.chiTName,
    required super.chiSName,
    required super.coordinate,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) =>
      _$BusStopFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$BusStopToJson(this);
}
