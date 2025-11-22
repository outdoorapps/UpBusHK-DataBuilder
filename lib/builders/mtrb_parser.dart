import 'dart:convert';
import 'dart:io';

import 'package:up_bus_hk_core/enums/bound.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';

class MtrbParser {
  static final _chineseMatcher = RegExp(r'^[\u4E00-\u9FFF\s\(\)【】0-9、]+');
  static final _stopIdMatcher = RegExp(
    r'^(K[0-9]+[A-Z]*\*?|506)-[a-z]?[UD][0-9]{3}$',
  );
  static const String _TSUEN_CODE = '&#37032;';
  static const String _TSUEN_CHARACTER = '邨';

  /// Parses the MTR Bus data file into a nested map:
  /// routeNumber -> bound -> List<BusStop>
  static Future<(List<CompanyBusRoute>, List<BusStop>)> parseMtrbData(
    String filePath,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('MTRB data file not found: $filePath');
    }

    final routes = <CompanyBusRoute>[];
    final stops = <BusStop>[];

    String? number;
    Bound? bound;
    final routeStops = <BusStop>[];

    final lines = await file.readAsLines(encoding: utf8);
    for (final line in lines) {
      if (line.startsWith('#') || line.isEmpty) {
        // Comments, do nothing
      } else if (line.startsWith('Route')) {
        // Flush completed routes
        if (number != null && bound != null) {
          final route = _buildRoute(number, bound, routeStops);
          routes.add(route);

          // Clean up for next route
          routeStops.clear();
          number = null;
          bound = null;
          routeStops.clear();
        }

        // Starts new route
        final parts = line.split(RegExp(r'\s+'));
        number = parts[1];
        final type = parts[2].substring(1, parts[2].length - 1);
        bound = switch (type) {
          'Outbound' || 'Single Direction' || 'Circular' => Bound.O,
          'Inbound' => Bound.I,
          _ => null,
        };
      } else if (_stopIdMatcher.hasMatch(line)) {
        final stop = _parseStopLine(line);
        routeStops.add(stop);
        stops.add(stop);
      }
    }

    // Flush last route
    if (number != null && bound != null) {
      final route = _buildRoute(number, bound, routeStops);
      routes.add(route);
    }
    return (routes, stops);
  }

  static CompanyBusRoute _buildRoute(
    String number,
    Bound bound,
    List<BusStop> routeStops,
  ) {
    final origin = routeStops.first;
    final dest = routeStops.last;

    return CompanyBusRoute(
      company: Company.MTRB,
      number: number,
      bound: bound,
      originE: origin.nameE,
      originC: origin.nameC,
      destE: dest.nameE,
      destC: dest.nameC,
      serviceType: null,
      nlbRouteId: null,
      stops: routeStops.map((e) => e.stopId).toList(),
    );
  }

  static BusStop _parseStopLine(String line) {
    final parts = line.split(RegExp(r'\s+'));

    final stopId = parts[0];
    final lat = double.tryParse(parts[1]) ?? 0.0;
    final long = double.tryParse(parts[2]) ?? 0.0;

    // Stop names
    final remainder = parts.sublist(3).join(' ');

    final chiMatch = _chineseMatcher.firstMatch(remainder)?.group(0) ?? '';
    final nameC = chiMatch.trim().replaceAll(_TSUEN_CODE, _TSUEN_CHARACTER);
    final nameE = chiMatch.isEmpty
        ? remainder.trim()
        : remainder.substring(chiMatch.length).trim();

    return BusStop(
      company: Company.MTRB,
      stopId: stopId,
      nameC: nameC,
      nameE: nameE,
      latLng: LatLng(lat: lat, long: long),
    );
  }
}
