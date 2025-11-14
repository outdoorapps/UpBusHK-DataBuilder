import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:isar_community/isar.dart';
import 'package:upbushk_data_builder/files/project_paths.dart';
import 'package:upbushk_data_builder/isar/models/bus_route.dart';
import 'package:upbushk_data_builder/isar/models/bus_stop.dart';
import 'package:upbushk_data_builder/isar/models/minibus_route.dart';
import 'package:upbushk_data_builder/isar/models/minibus_stop.dart';
import 'package:upbushk_data_builder/isar/models/track.dart';

import 'models/company_bus_route.dart';

Isar get isar => GetIt.I<Isar>();

class IsarManager {
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

    final isar = await Isar.open([
      CompanyBusRouteSchema,
      BusRouteSchema,
      BusStopSchema,
      MinibusRouteSchema,
      MinibusStopSchema,
      TrackSchema,
    ], directory: ProjectPaths.isarDir.path);

    GetIt.I.registerSingleton<Isar>(isar);
  }
}
