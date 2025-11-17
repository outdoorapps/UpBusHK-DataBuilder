import 'dart:io';

import 'package:up_bus_hk_core/enums/company.dart';
import 'package:up_bus_hk_core/isar/builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';
import 'package:up_bus_hk_data_builder/builders/mtrb_parser.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/network/data_services.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';
import 'package:up_bus_hk_data_builder/utils/async_utils.dart';

class BusStopBuilder {
  static Future<List<BusStop>> buildKmbStops() async {
    print('Building KMB stops...');
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
        engName: e.nameEn,
        chiTName: e.nameTc,
        latLng: latLng,
      );
    }).toList();
    stdout.writeln('Done');
    return stops;
  }

  static Future<List<BusStop>> buildCtbStops(
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
          engName: ctbStop.nameEn,
          chiTName: ctbStop.nameTc,
          latLng: latLng,
        );
      },
    );
    return stops.whereType<BusStop>().toList();
  }

  static Future<List<BusStop>> buildNlbStops(
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
                engName: s.stopNameE,
                chiTName: s.stopNameC,
                latLng: latLng,
              );
            }).toList();
          },
        );

    // Deduplicate with Set
    final stops = results.expand((x) => x).toSet().toList()
      ..sort((a, b) => a.stopId.compareTo(b.stopId));
    return stops;
  }

  static Future<List<BusStop>> buildMtrbStops() async {
    stdout.write('Building MTRB stops...');
    final mtrbRouteMap = await MtrbParser.parseMtrbData(
      ProjectPaths.mtrbDataPath,
    );
    final stops = mtrbRouteMap.values
        .expand((boundMap) => boundMap.values)
        .expand((stops) => stops)
        .toList();
    stdout.writeln('Building KMB stops...');
    return stops;
  }

  static Set<String> validateStops(
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
