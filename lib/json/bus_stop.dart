import 'package:json_annotation/json_annotation.dart';

part '../generated/json/bus_stop.g.dart';

@JsonSerializable()
class BusStop {
  final String company;
  final String stopId;
  final String engName;
  final String chiTName;
  final String chiSName;
  final List<double> coordinate;

  BusStop({
    required this.company,
    required this.stopId,
    required this.engName,
    required this.chiTName,
    required this.chiSName,
    required this.coordinate,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) => _$BusStopFromJson(json);
  Map<String, dynamic> toJson() => _$BusStopToJson(this);
}
