import 'package:isar_community/isar.dart';
import 'package:upbushk_data_builder/builders/bus_stop_builder.dart';
import 'package:upbushk_data_builder/builders/company_route_builder.dart';
import 'package:upbushk_data_builder/debug/benchmark.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/isar_manager.dart';
import 'package:upbushk_data_builder/isar/models/bus_stop.dart';
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
  await Benchmark.executeAsync('Building bus stops....', _buildBusStops);
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
  final ctbRoutes = await CompanyRouteBuilder.buildCtbRoutes();
  final nlbRoutes = await CompanyRouteBuilder.buildNlbRoutes();
  final mtrbRoutes = await CompanyRouteBuilder.buildNlbRoutes();

  final companyRoutes = [
    ...kmbRoutes,
    ...ctbRoutes,
    ...nlbRoutes,
    ...mtrbRoutes,
  ];
  companyRoutes.sort((a, b) => a.number.compareTo(b.number));

  print(
    '- KMB routes: ${kmbRoutes.length}, '
    '- CTB routes: ${ctbRoutes.length}, '
    '- NLB routes: ${nlbRoutes.length}, '
    '- MTRB routes: ${mtrbRoutes.length} '
    'Total: ${companyRoutes.length}',
  );

  await isar.writeTxn(() async {
    await isar.companyBusRoutes.clear();
    await isar.companyBusRoutes.putAll(companyRoutes);
  });
}

Future<void> _buildBusStops() async {
  final kmbStops = await BusStopBuilder.buildKmbStops();

  final ctbCompanyBusRoute = await isar.companyBusRoutes
      .filter()
      .companyEqualTo(Company.CTB)
      .findAll();
  final ctbStops = await BusStopBuilder.buildCtbStops(ctbCompanyBusRoute);

  final nlbCompanyBusRoute = await isar.companyBusRoutes
      .filter()
      .companyEqualTo(Company.NLB)
      .findAll();
  final nlbStops = await BusStopBuilder.buildNlbStops(nlbCompanyBusRoute);

  final mtrbStops = await BusStopBuilder.buildMtrbStops();

  final busStops = [...kmbStops, ...ctbStops, ...nlbStops, ...mtrbStops];

  print(
    '- KMB stops: ${kmbStops.length}, '
    '- CTB stops: ${ctbStops.length}, '
    '- NLB stops: ${nlbStops.length}, '
    '- MTRB stops: ${mtrbStops.length} '
    'Total: ${busStops.length}',
  );

  await isar.writeTxn(() async {
    await isar.busStops.clear();
    await isar.busStops.putAll(busStops);
  });
}
