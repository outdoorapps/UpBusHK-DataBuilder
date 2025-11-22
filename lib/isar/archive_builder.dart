import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/isar/models/db_version.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';

import 'isar_manager.dart';

class ArchiveBuilder {
  static const _dateFormat = "yyyyMMdd'T'HHmmss'Z'";

  static Future<void> build() async {
    final file = File(ProjectPath.appIsarPath);
    if (!await file.exists()) throw Exception('App isar file not found');

    final now = DateTime.now().toUtc();
    final created = DateFormat(_dateFormat).format(now);

    await isar.writeTxn(() => isar.dBVersions.put(DBVersion(created)));

    final outPath = join(
      ProjectPath.isarDir.path,
      'UpBusHK-DB_$created.tar.xz',
    );

    final data = await file.readAsBytes();
    final archive = Archive()
      ..addFile(ArchiveFile('default.isar', data.length, data));

    final tar = TarEncoder().encodeBytes(archive);
    final xz = XZEncoder().encodeBytes(tar); //todo no compression supported
    final outputFile = File(outPath);
    await outputFile.writeAsBytes(xz);

    print('Created: $outPath');
  }
}
