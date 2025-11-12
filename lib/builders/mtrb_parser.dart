import 'dart:convert';
import 'dart:io';

import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/enums/enums.dart';
import 'package:upbushk_data_builder/isar/models/bus_stop.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/utils/utils.dart';

class MtrbParser {
  static const String _TSUEN_CODE = '&#37032;';
  static const String _TSUEN_CHARACTER = '邨';
  static final _mtrbRouteRegex = RegExp(r'K[0-9]+[A-Z]?|506');
  static final _boundRegex = RegExp(r'(?<=\().+?(?=\))');
  static final _stopIdRegex = RegExp(
    r'^(K[0-9]+[A-Z]?|506)-[a-z]?[A-Z][0-9]{3}',
  );
  static final _chiNameRegex = RegExp(r'(\p{Han})+[^=A-Z]*', unicode: true);

  /// Parses the MTR Bus data file into a nested map:
  /// routeNumber -> bound -> List<BusStop>
  static Future<Map<String, Map<Bound, List<BusStop>>>> parseMtrbData(
    String filePath,
  ) async {
    final routeMap = <String, Map<Bound, List<BusStop>>>{};

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('MTRB data file not found: $filePath');
    }

    final lines = await file.readAsLines(encoding: utf8);

    String? number;
    Bound? bound;

    for (final line in lines) {
      if (line.startsWith('Route')) {
        number = _mtrbRouteRegex.firstMatch(line)?.group(0);
        final boundText = _boundRegex.firstMatch(line)?.group(0);
        bound = switch (boundText) {
          'Outbound' || 'Single Direction' => Bound.O,
          'Inbound' => Bound.I,
          _ => null,
        };

        if (number != null && bound != null) {
          routeMap.putIfAbsent(number, () => {});
          routeMap[number]!.putIfAbsent(bound, () => []);
        }
      } else if (_stopIdRegex.hasMatch(line)) {
        final items = line.split(' ');
        if (items.length < 3) continue;

        final stopId = items[0];
        final lat = double.tryParse(items[1]) ?? 0.0;
        final long = double.tryParse(items[2]) ?? 0.0;

        final chiNameText = _chiNameRegex.firstMatch(line)?.group(0);
        if (chiNameText == null) continue;

        var chiName = chiNameText.trim().replaceAll(
          _TSUEN_CODE,
          _TSUEN_CHARACTER,
        );
        final chiSName = Utils.zhT2S.convert(chiName);
        final engName = line
            .substring(line.indexOf(chiNameText) + chiNameText.length)
            .trim();

        final stop = BusStop(
          company: Company.MTRB,
          stopId: stopId,
          engName: engName,
          chiTName: chiName,
          chiSName: chiSName,
          coordinate: LatLng(lat: lat, long: long),
        );

        if (number != null && bound != null) {
          routeMap[number]![bound]!.add(stop);
        }
      }
    }

    return routeMap;
  }
}
