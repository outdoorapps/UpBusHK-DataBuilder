import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/isar/models/db_version.dart';
import 'package:up_bus_hk_core/isar/up_bus_hk_schema.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';

import 'isar_manager.dart';

class ArchiveBuilder {
  static const _dateFormat = "yyyyMMdd'T'HHmmss'Z'";
  static const _xzEncoder = 'xz';

  static Future<void> build() async {
    final isarFile = File(ProjectPath.appIsarPath);
    if (!await isarFile.exists()) throw Exception('App isar file not found');

    final now = DateTime.now().toUtc();
    final createdAt = DateFormat(_dateFormat).format(now);
    final outName = 'UpBusHK-DB_$createdAt.xz';
    final outPath = join(ProjectPath.outputDir.path, outName);

    await isar.writeTxn(() => isar.dBVersions.put(DBVersion(createdAt)));
    await isar.close();

    final hasXz = await _hasXz();
    if (!hasXz) throw ('No xz encoder installed');

    final result = await Benchmark.executeAsync(
      'Compressing',
      () => Process.run(_xzEncoder, ['-9', ProjectPath.appIsarPath]),
    );

    if (result.exitCode != 0) throw Exception('Failed:\n${result.stderr}');

    // Rename/move the output
    final compressedPath = '${ProjectPath.appIsarPath}.xz';
    await File(compressedPath).rename(outPath);

    final valid = await Benchmark.executeAsync(
      'Validating',
      () => _validate(outPath, createdAt),
    );
    valid ? print('Validated: $outPath') : print('Compress file corrupted');
  }

  static Future<bool> _hasXz() async {
    try {
      final result = await Process.run(_xzEncoder, ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _validate(String xzPath, String createdAt) async {
    const temp = 'temp';
    final xzFile = File(xzPath);
    final inputBytes = await xzFile.readAsBytes();
    final decodedBytes = XZDecoder().decodeBytes(inputBytes);

    // Create temp isar file
    final output = OutputFileStream(
      join(ProjectPath.outputDir.path, '$temp.isar'),
    );
    output.writeBytes(decodedBytes);
    await output.close();

    // Validate the data is correct
    final tempIsar = await Isar.open(
      UpBusHkSchema.appSchemas,
      directory: ProjectPath.outputDir.path,
      name: temp,
    );
    final dbVersion = await tempIsar.dBVersions.where().findFirst();
    final dbCreatedAt = dbVersion?.createdAt;
    final valid = dbCreatedAt == createdAt;

    // Clean up
    await tempIsar.close(deleteFromDisk: true);
    final lock = await File(join(ProjectPath.outputDir.path, '$temp.isar'));
    if (await lock.exists()) await lock.delete();

    return valid;
  }
}
