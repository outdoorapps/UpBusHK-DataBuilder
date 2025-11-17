import 'dart:io';

import 'package:path/path.dart';

class ProjectPaths {
  static final Directory projectRoot = Directory.current.parent;

  static final resourcesDir = Directory(join(projectRoot.path, 'resources'));
  static final dataDir = Directory(join(projectRoot.path, 'data'));

  static final govDataDir  = Directory(join(resourcesDir.path, 'govData'));
  static final generatedDir = Directory(join(resourcesDir.path, 'generated'));
  static final debugDir = Directory(join(resourcesDir.path, 'debug'));
  static final isarDir = Directory(join(resourcesDir.path, 'isar'));

  static String get busRoutesGeoJsonPath =>
      join(govDataDir.path, 'BusRoute_GEOJSON.zip');

  static String get busStopsGeoJsonPath =>
      join(govDataDir.path, 'CoordinateofBusStopLocation_GEOJSON.zip');

  static String get busRouteStopJsonPath =>
      join(govDataDir.path, 'JSON_BUS.json');

  static String get minibusDataJsonPath =>
      join(govDataDir.path, 'JSON_GMB.json');

  static String get govStopCoordinatesJsonPath =>
      join(govDataDir.path, 'STOP_BUS.gdb_converted.json');

  static String get busFarePath => join(govDataDir.path, 'FARE_BUS.xml');

  static String get mtrbDataPath => join(dataDir.path, 'mtrb.txt');

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
