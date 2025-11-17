import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/isar/up_bus_hk_schema.dart';
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
      UpBusHkSchema.builderSchemas,
      directory: ProjectPaths.isarDir.path,
      name: 'builder',
    );
    await builderIsar.writeTxn(() => builderIsar.clear());

    final isar = await Isar.open(
      UpBusHkSchema.schemas,
      directory: ProjectPaths.isarDir.path,
    );
    await isar.writeTxn(() => isar.clear());

    GetIt.I.registerSingleton<Isar>(builderIsar, instanceName: builderIsarName);
    GetIt.I.registerSingleton<Isar>(isar, instanceName: defaultIsarName);
  }
}
