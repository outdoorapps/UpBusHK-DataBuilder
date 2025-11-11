import 'package:isar_community/isar.dart';
import 'package:upbushk_data_builder/builders/company_route_builder.dart';
import 'package:upbushk_data_builder/debug/benchmark.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/isar_manager.dart';
import 'package:upbushk_data_builder/isar/models/company_bus_route.dart';
import 'package:upbushk_data_builder/network/links.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

void main() async {
  await Benchmark.executeAsync('Initializing....', _init);
  // await Benchmark.executeAsync('Downloading gov data....', _downloadGovData);
  await Benchmark.executeAsync(
    'Building company bus routes....',
    _buildCompanyBusRoutes,
  );
}

Future<void> _init() async {
  final firstTimeUse = await ProjectPaths.initDirectories();

  await Isar.initializeIsarCore(download: firstTimeUse);
  await IsarManager.init();
}

Future<void> _downloadGovData() async {
  final urlToPath = {
    Links.busRouteGeoJsonUrl: ProjectPaths.busRoutesGeoJsonPath,
    Links.busStopsGeoJsonUrl: ProjectPaths.busStopsGeoJsonPath,
    Links.busRouteStopUrl: ProjectPaths.busRouteStopJsonPath,
    Links.minibusRoutesGeoJsonUrl: ProjectPaths.minibusRoutesJsonPath,
    Links.fareUrl: ProjectPaths.busFarePath,
  };

  await WebServices.downloadAll(urlToPath);
}

Future<void> _buildCompanyBusRoutes() async {
  final kmbRoutes = await CompanyRouteBuilder.buildKmbRoutes();
  final ctbRoutes =
      <CompanyBusRoute>[]; // await CompanyRouteBuilder.buildCtbRoutes();

  print('${kmbRoutes.length}');

  final companyRoutes = [...kmbRoutes, ...ctbRoutes];
  companyRoutes.sort((a, b) => a.number.compareTo(b.number));

  await isar.writeTxn(() async {
    await isar.companyBusRoutes.clear();
    await isar.companyBusRoutes.putAll(companyRoutes);
  });
}
