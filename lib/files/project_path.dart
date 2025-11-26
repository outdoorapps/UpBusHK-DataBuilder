import 'dart:io';

import 'package:path/path.dart';

class ProjectPath {
  // Only works if calling from a child directory of the project root.
  static final projectRoot = File.fromUri(Platform.script).parent.parent;

  static final resourcesDir = Directory(join(projectRoot.path, 'resources'));
  static final dataDir = Directory(join(projectRoot.path, 'data'));

  static final govDataDir = Directory(join(resourcesDir.path, 'govData'));
  static final isarDir = Directory(join(resourcesDir.path, 'isar'));
  static final outputDir = Directory(join(resourcesDir.path, 'output'));

  static String busRoutesGeoJson = join(
    govDataDir.path,
    'BusRoute_GEOJSON.zip',
  );

  static String busStopsGeoJson = join(
    govDataDir.path,
    'CoordinateofBusStopLocation_GEOJSON.zip',
  );

  static String busRouteStopJson = join(govDataDir.path, 'JSON_BUS.json');

  static String minibusDataJson = join(govDataDir.path, 'JSON_GMB.json');

  static String busFare = join(govDataDir.path, 'FARE_BUS.xml');

  static String mtrbData = join(dataDir.path, 'mtrb.txt');

  static String appIsar = join(isarDir.path, 'default.isar');

  /// Ensures all required folders exist before use.
  static Future<void> initDirectories() async {
    for (final dir in [resourcesDir, dataDir, govDataDir, isarDir, outputDir]) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        stdout.writeln('Created ${dir.path}');
      }
    }
  }
}
