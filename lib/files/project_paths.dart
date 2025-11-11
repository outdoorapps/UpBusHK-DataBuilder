import 'dart:io';

class ProjectPaths {
  static final resourcesDir = Directory('resources');
  static final govDataDir = Directory('resources/govData');
  static final generatedDir = Directory('resources/generated');
  static final debugDir = Directory('resources/debug');
  static final dataDir = Directory('data');

  static String get busRoutesGeoJsonPath =>
      '${govDataDir.path}/BusRoute_GEOJSON.zip';

  static String get busStopsGeoJsonPath =>
      '${govDataDir.path}/CoordinateofBusStopLocation_GEOJSON.zip';

  static String get busRouteStopJsonPath => '${govDataDir.path}/JSON_BUS.json';

  static String get minibusRoutesJsonPath => '${govDataDir.path}/JSON_GMB.json';

  static String get busFarePath => '${govDataDir.path}/FARE_BUS.xml';

  /// Ensures all required folders exist before use.
  static Future<void> initDirectories() async {
    for (final dir in [
      resourcesDir,
      govDataDir,
      generatedDir,
      debugDir,
      dataDir,
    ]) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        stdout.writeln('Created ${dir.path}');
      }
    }
  }
}
