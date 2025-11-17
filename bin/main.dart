import 'package:up_bus_hk_data_builder/builders/bus_stop_builder.dart';
import 'package:up_bus_hk_data_builder/builders/company_route_builder.dart';
import 'package:up_bus_hk_data_builder/builders/gov_bus_builder.dart';
import 'package:up_bus_hk_data_builder/builders/minibus_builder.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/network/links.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';
import 'package:up_bus_hk_data_builder/files/extractor.dart';

void main() async {
  await Benchmark.executeAsync('Initializing', _init);
  // await Benchmark.executeAsync('Downloading gov data', _downloadGovData);
  // await Benchmark.executeAsync('Extracting files', _extractFiles);

  await Benchmark.executeAsync(
    'Building company bus routes',
    CompanyRouteBuilder.build,
  );
  await Benchmark.executeAsync('Building bus stops', BusStopBuilder.build);

  await Benchmark.executeAsync('Building minibus data', MinibusBuilder.build);

  await Benchmark.executeAsync('Building gov bus data', GovBusBuilder.build);
}

Future<void> _init() async {
  await IsarManager.init(clearPreviousData: true);
}

Future<void> _downloadGovData() async {
  final urlToPath = {
    Links.busRouteGeoJsonUrl: ProjectPath.busRoutesGeoJsonPath,
    Links.busStopsGeoJsonUrl: ProjectPath.busStopsGeoJsonPath,
    Links.busRouteStopUrl: ProjectPath.busRouteStopJsonPath,
    Links.minibusRoutesGeoJsonUrl: ProjectPath.minibusDataJsonPath,
    Links.fareUrl: ProjectPath.busFarePath,
  };
  await WebServices.downloadAll(urlToPath);
}

Future<void> _extractFiles() async {
  // await Extractor.extractZipFile(
  //   ProjectPath.busRoutesGeoJsonPath,
  //   ProjectPath.govDataDir.path,
  // );

  await Extractor.extractZipFile(
    ProjectPath.busStopsGeoJsonPath,
    ProjectPath.govDataDir.path,
  );
}
