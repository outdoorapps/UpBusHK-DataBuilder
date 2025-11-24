import 'package:up_bus_hk_data_builder/builders/bus_route_builder.dart';
import 'package:up_bus_hk_data_builder/builders/bus_stop_builder.dart';
import 'package:up_bus_hk_data_builder/builders/company_route_builder.dart';
import 'package:up_bus_hk_data_builder/builders/gov_bus_builder.dart';
import 'package:up_bus_hk_data_builder/builders/minibus_builder.dart';
import 'package:up_bus_hk_data_builder/builders/track_builder.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/builders/xz_builder.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/network/links.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';

// todo Updated every time when there are breaking changes
const minAppVersion = '1.3.0';

void main() async {
  await Benchmark.executeAsync('Building UpBusHK data', _build);
}

Future<void> _build() async {
  await Benchmark.executeAsync(
    'Initializing',
    () async => await IsarManager.init(clearPreviousData: true),
  );

  await Benchmark.executeAsync('Downloading gov data', () async {
    final urlToPath = {
      Links.busRouteGeoJsonUrl: ProjectPath.busRoutesGeoJsonPath,
      Links.busStopsGeoJsonUrl: ProjectPath.busStopsGeoJsonPath,
      Links.busRouteStopUrl: ProjectPath.busRouteStopJsonPath,
      Links.minibusRoutesGeoJsonUrl: ProjectPath.minibusDataJsonPath,
      Links.fareUrl: ProjectPath.busFarePath,
    };
    await WebServices.downloadAll(urlToPath);
  });

  await Benchmark.executeAsync(
    'Building company bus routes',
    CompanyRouteBuilder.build,
  );

  await Benchmark.executeAsync('Building bus stops', BusStopBuilder.build);

  await Benchmark.executeAsync('Building minibus data', MinibusBuilder.build);

  await Benchmark.executeAsync('Building gov bus data', GovBusBuilder.build);

  await Benchmark.executeAsync('Building bus routes', BusRouteBuilder.build);

  await Benchmark.executeAsync('Building tracks', TrackBuilder.build);

  await Benchmark.executeAsync('Building archive', XzBuilder.build);

  // todo uploader
}
