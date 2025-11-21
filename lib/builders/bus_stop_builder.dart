import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_core/isar/embedded/lat_lng.dart';
import 'package:up_bus_hk_data_builder/builders/mtrb_parser.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/isar/isar_manager.dart';
import 'package:up_bus_hk_data_builder/network/data_services.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';
import 'package:up_bus_hk_data_builder/utils/async_utils.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';
import 'package:up_bus_hk_data_builder/utils/patch.dart';

class BusStopBuilder {
  /// Use the [CompanyBusRoute] stored in Isar and fetch from the online APIs
  /// to build a list of [BusStop] and save them to Isar.
  static Future<void> build({bool clearPreviousData = false}) async {
    if (clearPreviousData) {
      await isar.writeTxn(() async => isar.busStops.clear());
    }

    final kmbStops = await Benchmark.executeAsync(
      'Building KMB stops',
      _buildKmbStops,
    );

    final ctbCompanyBusRoute = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.CTB)
        .findAll();
    final ctbStops = await _buildCtbStops(ctbCompanyBusRoute);

    final nlbCompanyBusRoute = await builderIsar.companyBusRoutes
        .filter()
        .companyEqualTo(Company.NLB)
        .findAll();
    final nlbStops = await _buildNlbStops(nlbCompanyBusRoute);

    final mtrbStops = await Benchmark.executeAsync(
      'Building MTRB stops',
      _buildMtrbStops,
    );

    final busStops = [...kmbStops, ...ctbStops, ...nlbStops, ...mtrbStops];
    await isar.writeTxn(() async => await isar.busStops.putAll(busStops));

    final companyBusRoutes = await builderIsar.companyBusRoutes
        .where()
        .findAll();
    _validateStops(companyBusRoutes, busStops);

    print(
      '- KMB stops: ${kmbStops.length}'
      '\n- CTB stops: ${ctbStops.length}'
      '\n- NLB stops: ${nlbStops.length}'
      '\n- MTRB stops: ${mtrbStops.length}'
      '\n- Total: ${busStops.length}',
    );
  }

  static Future<List<BusStop>> _buildKmbStops() async {
    final response = await WebServices.kmb.getStops();
    final stops = response.data.map((e) {
      final lat = double.tryParse(e.lat);
      final long = double.tryParse(e.lng);
      final latLng = lat != null && long != null
          ? LatLng(lat: lat, long: long)
          : LatLng.empty();

      return BusStop(
        company: Company.KMB,
        stopId: e.stop,
        nameE: e.nameEn,
        nameC: e.nameTc,
        latLng: latLng,
      );
    }).toList();
    return stops;
  }

  static Future<List<BusStop>> _buildCtbStops(
    List<CompanyBusRoute> ctbCompanyBusRoutes,
  ) async {
    // Collect all unique stop IDs from all routes
    final ctbBusCompanyRoutes = ctbCompanyBusRoutes.where(
      (r) => r.company == Company.CTB,
    );
    final pendingStopIds = ctbBusCompanyRoutes.expand((r) => r.stops).toSet();

    final allStops = <BusStop>[];

    await WebServices.retryBatch<String>(
      pending: pendingStopIds,
      pendingTypeLabel: "CTB stop ID",
      work: (pendingIDs) async {
        final stops = await _getCtbStops(pendingIDs);
        allStops.addAll(stops);
        return stops.map((s) => s.stopId).toSet();
      },
    );

    allStops.sort((a, b) => a.stopId.compareTo(b.stopId));
    return allStops;
  }

  static Future<List<BusStop>> _getCtbStops(Set<String> stopIds) async {
    final stops = await AsyncUtils.mapAsyncWithProgress<String, BusStop?>(
      items: stopIds,
      label: "Building CTB stops",
      worker: (stopId) async {
        final ctbStop = await DataServices.getCtbStop(stopId);
        if (ctbStop == null) return null;

        final lat = double.tryParse(ctbStop.lat);
        final long = double.tryParse(ctbStop.long);
        final latLng = lat != null && long != null
            ? LatLng(lat: lat, long: long)
            : LatLng.empty();

        return BusStop(
          company: Company.CTB,
          stopId: ctbStop.stop,
          nameE: ctbStop.nameEn,
          nameC: ctbStop.nameTc,
          latLng: latLng,
        );
      },
    );
    return stops.whereType<BusStop>().toList();
  }

  static Future<List<BusStop>> _buildNlbStops(
    List<CompanyBusRoute> nlbCompanyBusRoutes,
  ) async {
    final results =
        await AsyncUtils.mapAsyncWithProgress<CompanyBusRoute, List<BusStop>>(
          items: nlbCompanyBusRoutes,
          label: "Building NLB stops",
          worker: (route) async {
            final response = await WebServices.gov.getNlbRouteStops(
              route.nlbRouteId!,
            );

            return response.stops.map((s) {
              final lat = double.tryParse(s.latitude);
              final long = double.tryParse(s.longitude);
              final latLng = lat != null && long != null
                  ? LatLng(lat: lat, long: long)
                  : LatLng.empty();

              return BusStop(
                company: Company.NLB,
                stopId: s.stopId,
                nameE: s.stopNameE,
                nameC: s.stopNameC,
                latLng: Patch.stopIdToLatLng[s.stopId] ?? latLng,
              );
            }).toList();
          },
        );

    // Deduplicate with Set
    final stops = results.expand((x) => x).toSet().toList()
      ..sort((a, b) => a.stopId.compareTo(b.stopId));
    return stops;
  }

  static Future<List<BusStop>> _buildMtrbStops() async {
    final mtrbRouteMap = await MtrbParser.parseMtrbData(
      ProjectPath.mtrbDataPath,
    );
    final stops = mtrbRouteMap.values
        .expand((boundMap) => boundMap.values)
        .expand((stops) => stops)
        .toList();
    return stops;
  }

  static Set<String> _validateStops(
    List<CompanyBusRoute> companyBusRoutes,
    List<BusStop> busStops,
  ) {
    final stopIDsInRoutes = companyBusRoutes.expand((e) => e.stops).toSet();
    final stopIDsInDatabase = busStops.map((e) => e.stopId).toSet();
    final missingStops = <String>{};

    stopIDsInRoutes.forEach((stopId) {
      if (!stopIDsInDatabase.contains(stopId)) {
        missingStops.add(stopId);
      }
    });

    missingStops.forEach(
      (stopId) => print('Bus stop [$stopId] is not in the database'),
    );
    if (missingStops.isEmpty) print('Bus stops validated');

    return missingStops;
  }
}
