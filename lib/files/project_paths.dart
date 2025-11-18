import 'dart:io';

import 'package:path/path.dart';

class ProjectPath {
  // Only works if calling from a child directory of the project root.
  static final Directory projectRoot = File.fromUri(
    Platform.script,
  ).parent.parent;

  static final resourcesDir = Directory(join(projectRoot.path, 'resources'));
  static final dataDir = Directory(join(projectRoot.path, 'data'));

  static final govDataDir = Directory(join(resourcesDir.path, 'govData'));
  static final generatedDir = Directory(join(resourcesDir.path, 'generated'));
  static final debugDir = Directory(join(resourcesDir.path, 'debug'));
  static final isarDir = Directory(join(resourcesDir.path, 'isar'));

  static String busRoutesGeoJsonPath = join(
    govDataDir.path,
    'BusRoute_GEOJSON.zip',
  );

  static String busStopsGeoJsonPath = join(
    govDataDir.path,
    'CoordinateofBusStopLocation_GEOJSON.zip',
  );

  static String busRouteStopJsonPath = join(govDataDir.path, 'JSON_BUS.json');

  static String minibusDataJsonPath = join(govDataDir.path, 'JSON_GMB.json');

  static String govStopCoordinatesJsonPath = join(
    govDataDir.path,
    'STOP_BUS.gdb_converted.geojson',
  );

  static String busFarePath = join(govDataDir.path, 'FARE_BUS.xml');

  static String mtrbDataPath = join(dataDir.path, 'mtrb.txt');

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
