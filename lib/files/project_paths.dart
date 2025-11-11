import 'dart:io';

import 'package:path/path.dart';

class ProjectPaths {
  static final resourcesDir = Directory('../resources');
  static final govDataDir = Directory(join(resourcesDir.path, 'govData'));
  static final generatedDir = Directory(join(resourcesDir.path, 'generated'));
  static final debugDir = Directory(join(resourcesDir.path, 'debug'));
  static final isarDir = Directory(join(resourcesDir.path, 'isar'));
  static final dataDir = Directory('../data');

  static String get busRoutesGeoJsonPath =>
      '${govDataDir.path}/BusRoute_GEOJSON.zip';

  static String get busStopsGeoJsonPath =>
      '${govDataDir.path}/CoordinateofBusStopLocation_GEOJSON.zip';

  static String get busRouteStopJsonPath => '${govDataDir.path}/JSON_BUS.json';

  static String get minibusRoutesJsonPath => '${govDataDir.path}/JSON_GMB.json';

  static String get busFarePath => '${govDataDir.path}/FARE_BUS.xml';

  /// Ensures all required folders exist before use.
  static Future<bool> initDirectories() async {
    bool created = false;
    for (final dir in [
      resourcesDir,
      govDataDir,
      generatedDir,
      debugDir,
      isarDir,
      dataDir,
    ]) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        stdout.writeln('Created ${dir.path}');
        created = true;
      }
    }
    return created;
  }
}
