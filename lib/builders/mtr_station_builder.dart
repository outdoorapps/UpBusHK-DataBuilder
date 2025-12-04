import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_core/isar/embedded/station_sequence.dart';
import 'package:up_bus_hk_core/isar/models/mtr_station.dart';
import 'package:up_bus_hk_data_builder/files/project_path.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/utils/patch.dart';

class MtrStationBuilder {
  static Future<void> build({bool clearPreviousData = false}) async {
    final stationIdToLatLng = await _getLocationMap();

    final file = File(ProjectPath.mtrLineAndStations);
    if (!await file.exists()) {
      throw Exception(
        'MTR data file not found: ${ProjectPath.mtrLineAndStations}',
      );
    }

    final mtrStations = <MtrStation>[];
    final csvText = await file.readAsString();
    final lines = const LineSplitter().convert(csvText).skip(1).toList();
    lines.forEach((e) {
      final l = e.replaceAll('"', '');
      final parts = l.split(',');
      if (parts.any((e) => e.isEmpty)) return; // skip empty lines

      final line = parts[0];
      final stationId = int.parse(parts[3]);
      final sequence = StationSequence(
        direction: parts[1],
        seq: double.parse(parts[6]).toInt(),
      );

      final existing = mtrStations.firstWhereOrNull(
        (s) => s.stationId == stationId,
      );
      if (existing == null) {
        mtrStations.add(
          MtrStation(
            lines: [line],
            stationCode: parts[2],
            stationId: stationId,
            nameE: parts[5],
            nameC: parts[4],
            latLng: stationIdToLatLng[stationId] ?? LatLng(),
            sequences: [sequence],
          ),
        );
      } else {
        existing.lines.add(line);
        existing.sequences.add(sequence);
      }
    });

    mtrStations.addAll(Patch.mtrStationsPatch);
    mtrStations..sort((a, b) => a.stationId.compareTo(b.stationId));

    isar.writeTxn(() async {
      if (clearPreviousData) await isar.mtrStations.clear();
      await isar.mtrStations.putAll(mtrStations);
    });
  }

  static Future<Map<int, LatLng>> _getLocationMap() async {
    final stationIdToLatLng = <int, LatLng>{};
    final file = File(ProjectPath.mtrStationsLocations);
    if (!await file.exists()) {
      throw Exception(
        'MTR location file not found: ${ProjectPath.mtrLineAndStations}',
      );
    }

    final csvText = await file.readAsString();
    final lines = const LineSplitter().convert(csvText).skip(1).toList();
    lines.forEach((line) {
      final l = line.replaceAll('"', '');
      final parts = l.split(',');
      final stationId = int.parse(parts[0]);
      final lat = double.parse(parts[2]);
      final lng = double.parse(parts[3].trim());
      stationIdToLatLng[stationId] = LatLng(lat: lat, long: lng);
    });
    return stationIdToLatLng;
  }
}
