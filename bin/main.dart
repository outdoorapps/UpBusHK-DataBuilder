import 'package:upbushk_data_builder/debug/benchmark.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/network/links.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

void main() async {
  Benchmark.executeAsync('Downloading gov data....', downloadGovData);
}

Future<void> downloadGovData() async {
  await ProjectPaths.initDirectories();

  final urlToPath = {
    Links.busRouteGeoJsonUrl: ProjectPaths.busRoutesGeoJsonPath,
    Links.busStopsGeoJsonUrl: ProjectPaths.busStopsGeoJsonPath,
    Links.busRouteStopUrl: ProjectPaths.busRouteStopJsonPath,
    Links.minibusRoutesGeoJsonUrl: ProjectPaths.minibusRoutesJsonPath,
    Links.fareUrl: ProjectPaths.busFarePath,
  };

  await WebServices.downloadAll(urlToPath);
}