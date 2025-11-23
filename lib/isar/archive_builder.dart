import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/isar/models/db_version.dart';
import 'package:up_bus_hk_core/isar/models/transit_route.dart';
import 'package:up_bus_hk_core/isar/up_bus_hk_schema.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';

import 'isar_manager.dart';

class ArchiveBuilder {
  static const _dateFormat = "yyyyMMdd'T'HHmmss'Z'";

  static Future<void> build() async {
    final isarFile = File(ProjectPath.appIsarPath);
    if (!await isarFile.exists()) throw Exception('App isar file not found');

    final now = DateTime.now().toUtc();
    final created = DateFormat(_dateFormat).format(now);
    final outName = 'UpBusHK-DB_$created.gz';
    final outPath = join(ProjectPath.outputDir.path, outName);

    await isar.writeTxn(() => isar.dBVersions.put(DBVersion(created)));
    final busRouteCount = await isar.busRoutes.where().count();
    isar.close();

    final input = InputFileStream(ProjectPath.appIsarPath);
    final output = OutputFileStream(outPath);
    GZipEncoder().encodeStream(input, output, level: 9);

    final valid = await _validate(outPath, busRouteCount);
    valid ? print('Archive created: $outPath') : print('Archive corrupted');
  }

  static Future<bool> _validate(String gzipPath, int busRouteCount) async {
    final archive = InputFileStream(gzipPath);
    final output = OutputFileStream(
      join(ProjectPath.outputDir.path, 'temp.isar'),
    );
    GZipDecoder().decodeStream(archive, output);

    final tempIsar = await Isar.open(
      UpBusHkSchema.appSchemas,
      directory: ProjectPath.outputDir.path,
      name: 'temp'
    );

    final routeCountInTemp = await tempIsar.busRoutes.where().count();
    tempIsar.close(deleteFromDisk: true);

    return routeCountInTemp == busRouteCount;
  }
}
