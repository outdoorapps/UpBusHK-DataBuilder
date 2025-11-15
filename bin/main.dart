import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_data_builder/builders/bus_stop_builder.dart';
import 'package:up_bus_hk_data_builder/builders/company_route_builder.dart';
import 'package:up_bus_hk_data_builder/builders/minibus_builder.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/network/links.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';

void main() async {
  await Benchmark.executeAsync('Initializing', _init);
  // await Benchmark.executeAsync('Downloading gov data....', _downloadGovData);

  await Benchmark.executeAsync(
    'Building company bus routes',
    _buildCompanyBusRoutes,
  );
  await Benchmark.executeAsync('Building bus stops', _buildBusStops);

  await Benchmark.executeAsync(
    'Building minibus data',
    MinibusBuilder.buildMinibusData,
  );
}

Future<void> _init() async {
  await IsarManager.init();
}

Future<void> _downloadGovData() async {
  final urlToPath = {
    Links.busRouteGeoJsonUrl: ProjectPaths.busRoutesGeoJsonPath,
    Links.busStopsGeoJsonUrl: ProjectPaths.busStopsGeoJsonPath,
    Links.busRouteStopUrl: ProjectPaths.busRouteStopJsonPath,
    Links.minibusRoutesGeoJsonUrl: ProjectPaths.minibusDataJsonPath,
    Links.fareUrl: ProjectPaths.busFarePath,
  };

  await WebServices.downloadAll(urlToPath);
}

Future<void> _buildCompanyBusRoutes() async {
  final kmbRoutes = await CompanyRouteBuilder.buildKmbRoutes();
  final ctbRoutes = await CompanyRouteBuilder.buildCtbRoutes();
  final nlbRoutes = await CompanyRouteBuilder.buildNlbRoutes();
  final mtrbRoutes = await CompanyRouteBuilder.buildMtrbRoutes();

  final companyRoutes = [
    ...kmbRoutes,
    ...ctbRoutes,
    ...nlbRoutes,
    ...mtrbRoutes,
  ];
  companyRoutes.sort((a, b) => a.number.compareTo(b.number));

  print(
    '- KMB routes: ${kmbRoutes.length}'
    '\n- CTB routes: ${ctbRoutes.length}'
    '\n- NLB routes: ${nlbRoutes.length}'
    '\n- MTRB routes: ${mtrbRoutes.length}'
    '\n- Total: ${companyRoutes.length}',
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

  final companyBusRoutes = await isar.companyBusRoutes.where().findAll();
  BusStopBuilder.validateStops(companyBusRoutes, busStops);

  print(
    '- KMB stops: ${kmbStops.length}, '
    '\n- CTB stops: ${ctbStops.length}, '
    '\n- NLB stops: ${nlbStops.length}, '
    '\n- MTRB stops: ${mtrbStops.length} '
    '\n- Total: ${busStops.length}',
  );

  await isar.writeTxn(() async {
    await isar.busStops.clear();
    await isar.busStops.putAll(busStops);
  });
}
