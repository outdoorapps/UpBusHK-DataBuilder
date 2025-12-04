import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_data_builder/files/project_path.dart';
import 'package:up_bus_hk_data_builder/isar/mtr_station.dart';

class MtrStationBuilder {
  static Future<void> build() async {
    final file = File(ProjectPath.mtrData);
    if (!await file.exists()) {
      throw Exception('MTRB data file not found: ${ProjectPath.mtrData}');
    }

    final csvText = await file.readAsString();
    final lines = const LineSplitter()
        .convert(csvText)
        .skip(1) // skip header
        .toList();
    final parsed = lines
        .map((l) => _parseDataLine(l))
        .whereType<MtrStation>()
        .toList();
    final mtrStations = groupBy(parsed, (s) => s.stationId).entries.map((e) {
      final station = e.value.first;
      e.value.skip(1).forEach((s) {
        station.lines.addAll(s.lines);
        station.sequences.addAll(s.sequences);
      });
      final uniqueLines = station.lines.toSet();
      station.lines
        ..clear()
        ..addAll(uniqueLines);
      return station;
    }).toList()..sort((a, b) => a.stationId.compareTo(b.stationId));

    // todo patch racecourse
    mtrStations.forEach((s) => print(s));

    // groupBy(mtrStations, (s) => s.nameE).forEach((line, stations) {
    //   if(stations.length > 1)print(line);
    // });
  }

  /// Very simple CSV parser for your dataset style
  static MtrStation? _parseDataLine(String line) {
    final l = line.replaceAll('"', '');
    final parts = l.split(',');
    return parts.any((e) => e.isEmpty)
        ? null
        : MtrStation(
            lines: [parts[0]],
            stationCode: parts[2],
            stationId: int.parse(parts[3]),
            nameE: parts[5],
            nameC: parts[4],
            latLng: LatLng(),
            sequences: [
              MtrStationSequence(
                direction: parts[1],
                seq: double.parse(parts[6]).toInt(),
              ),
            ],
          );
  }
}
