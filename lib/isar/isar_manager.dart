import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/bus_fare.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/company_bus_route.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/gov_bus_route.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/gov_route_stop.dart';
import 'package:up_bus_hk_core/isar/data_builder_models/gov_stop_coordinate.dart';
import 'package:up_bus_hk_core/isar/models/bus_route.dart';
import 'package:up_bus_hk_core/isar/models/bus_stop.dart';
import 'package:up_bus_hk_core/isar/models/minibus_route.dart';
import 'package:up_bus_hk_core/isar/models/minibus_stop.dart';
import 'package:up_bus_hk_core/isar/models/track.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';

/// For final app use
Isar get isar => GetIt.I<Isar>(instanceName: IsarManager.defaultIsarName);

/// For storing intermediates
Isar get builderIsar =>
    GetIt.I<Isar>(instanceName: IsarManager.builderIsarName);

class IsarManager {
  static const defaultIsarName = 'default';
  static const builderIsarName = 'builder';

  /// This must be called before any data is read
  /// For future reference: for any schema change, putting an updated database
  /// in the asset folder will trigger a database rebuild
  static Future<void> init() async {
    final f = File('bin/libisar.so');
    final download = !await f.exists();

    try {
      await Isar.initializeIsarCore(download: download);
    } on IsarError {
      // Try removing the old Isar Core binaries
      await f.delete();
      await Isar.initializeIsarCore(download: true);
    }

    final builderIsar = await Isar.open(
      [
        CompanyBusRouteSchema,
        BusFareSchema,
        GovRouteStopSchema,
        GovStopCoordinateSchema,
        GovBusRouteSchema,
      ],
      directory: ProjectPaths.isarDir.path,
      name: 'builder',
    );
    await builderIsar.writeTxn(() async {
      await builderIsar.clear();
    });

    final isar = await Isar.open([
      BusRouteSchema,
      BusStopSchema,
      MinibusRouteSchema,
      MinibusStopSchema,
      TrackSchema,
    ], directory: ProjectPaths.isarDir.path);

    await isar.writeTxn(() async {
      await isar.clear();
    });

    GetIt.I.registerSingleton<Isar>(builderIsar, instanceName: builderIsarName);
    GetIt.I.registerSingleton<Isar>(isar, instanceName: defaultIsarName);
  }
}
