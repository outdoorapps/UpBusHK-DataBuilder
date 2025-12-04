import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';

@collection
class MtrStation {
  Id id = Isar.autoIncrement;
  final List<String> lines;
  final String stationCode;
  final int stationId;
  final String nameE;
  final String nameC;

  final LatLng latLng;
  final List<MtrStationSequence> sequences;

  MtrStation({
    required this.lines,
    required this.stationCode,
    required this.stationId,
    required this.nameE,
    required this.nameC,
    required this.latLng,
    required this.sequences,
  });

  @override
  String toString() =>
      'MtrStation(line: $lines, '
      'stationCode: $stationCode, '
      'stationId: $stationId, '
      'nameE: $nameE, '
      'nameC: $nameC, '
      'latLng: $latLng, '
      'sequences: $sequences)';
}

@embedded
class MtrStationSequence {
  final String direction;
  final int seq;

  MtrStationSequence({required this.direction, required this.seq});

  @override
  String toString() => 'MtrStationSequence(direction: $direction, seq: $seq)';
}
