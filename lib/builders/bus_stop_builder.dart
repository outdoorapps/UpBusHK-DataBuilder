import 'dart:io';

import 'package:synchronized/synchronized.dart';
import 'package:upbushk_data_builder/builders/mtrb_parser.dart';
import 'package:upbushk_data_builder/enums/company.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/bus_stop.dart';
import 'package:upbushk_data_builder/isar/models/company_bus_route.dart';
import 'package:upbushk_data_builder/isar/models/lat_lng.dart';
import 'package:upbushk_data_builder/network/data_services.dart';
import 'package:upbushk_data_builder/network/web_services.dart';

class BusStopBuilder {
  static Future<List<BusStop>> buildKmbStops() async {
    final stops = await DataServices.getKmbStops();
    return stops.map((e) {
      return BusStop(
        company: Company.KMB,
        stopId: e.stop,
        engName: e.nameEn,
        chiTName: e.nameTc,
        chiSName: e.nameSc,
        latLng: LatLng(
          lat: double.tryParse(e.lat) ?? 0,
          long: double.tryParse(e.lng) ?? 0,
        ),
      );
    }).toList();
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
    int retries = 0;

    while (pendingStopIds.isNotEmpty && retries < WebServices.maxRetries) {
      final stops = await _getCtbStops(pendingStopIds);
      allStops.addAll(stops);

      // Remove successfully retrieved stops
      final retrievedStopsIds = stops.map((s) => s.stopId).toSet();
      pendingStopIds.removeAll(retrievedStopsIds);

      final remaining = pendingStopIds.length;
      if (remaining > 0) {
        print(
          '$remaining errors received for CTB stop IDs $pendingStopIds, '
          'waiting for ${WebServices.timeoutSeconds}s before retrying...',
        );
        await Future.delayed(Duration(seconds: WebServices.timeoutSeconds));
        print('Restarting...');
      }
    }
    allStops.sort((a, b) => a.stopId.compareTo(b.stopId));
    return allStops;
  }

  static Future<List<BusStop>> _getCtbStops(Set<String> stopIds) async {
    final List<BusStop> stops = [];
    final total = stopIds.length;
    final start = DateTime.now();
    final lock = Lock();
    int completed = 0;

    // Run all requests concurrently
    await Future.wait(
      stopIds.map((stopId) async {
        final ctbStop = await DataServices.getCtbStop(stopId);
        if (ctbStop != null) {
          stops.add(
            BusStop(
              company: Company.CTB,
              stopId: ctbStop.stop,
              engName: ctbStop.nameEn,
              chiTName: ctbStop.nameTc,
              chiSName: ctbStop.nameSc,
              latLng: LatLng(
                lat: double.tryParse(ctbStop.lat) ?? 0.0,
                long: double.tryParse(ctbStop.long) ?? 0.0,
              ),
            ),
          );
        }

        // Synchronized to ensure reporting is atomic
        lock.synchronized(() {
          completed++;
          if (completed % 50 == 0 || completed == total) {
            final percent = (completed / total * 100).toStringAsFixed(1);
            final elapsed = DateTime.now().difference(start).inSeconds;
            stdout.write(
              '\rProgress: $completed/$total  $percent%  (${elapsed}s)',
            );
            if (completed == total) stdout.writeln();
          }
        });
      }),
    );
    return stops;
  }

  static Future<List<BusStop>> buildNlbStops(
    List<CompanyBusRoute> nlbCompanyBusRoutes,
  ) async {
    final List<BusStop> nlbStops = [];
    final existingStopIds = <String>{};
    final total = nlbCompanyBusRoutes.length;
    final start = DateTime.now();
    final lock = Lock();
    var completed = 0;

    await Future.wait(
      nlbCompanyBusRoutes.map((route) async {
        final stops = await DataServices.getNlbRouteStops(route.nlbRouteId!);

        await lock.synchronized(() {
          for (final stop in stops) {
            if (!existingStopIds.contains(stop.stopId)) {
              existingStopIds.add(stop.stopId);
              nlbStops.add(
                BusStop(
                  company: Company.NLB,
                  stopId: stop.stopId,
                  engName: stop.stopNameE,
                  chiTName: stop.stopNameC,
                  chiSName: stop.stopNameS,
                  latLng: LatLng(
                    lat: double.tryParse(stop.latitude) ?? 0.0,
                    long: double.tryParse(stop.longitude) ?? 0.0,
                  ),
                ),
              );
            }
          }
        });

        await lock.synchronized(() {
          completed++;
          if (completed % 10 == 0 || completed == total) {
            final percent = (completed / total * 100).toStringAsFixed(1);
            final elapsed = DateTime.now().difference(start).inSeconds;
            stdout.write(
              '\rProgress: $completed/$total  $percent%  (${elapsed}s)',
            );
            if (completed == total) stdout.writeln();
          }
        });
      }),
    );

    nlbStops.sort((a, b) => a.stopId.compareTo(b.stopId));
    return nlbStops;
  }

  static Future<List<BusStop>> buildMtrbStops() async {
    final mtrbRouteMap = await MtrbParser.parseMtrbData(
      ProjectPaths.mtrbDataPath,
    );

    final List<BusStop> busStops = [];
    mtrbRouteMap.forEach((_, boundMap) {
      boundMap.forEach((_, stops) {
        busStops.addAll(stops);
      });
    });
    return busStops;
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
