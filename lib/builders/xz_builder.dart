import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/isar/models/meta.dart';
import 'package:up_bus_hk_core/isar/up_bus_hk_schema.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';

import '../isar/isar_manager.dart';

class XzBuilder {
  static const _dateFormat = "yyyyMMdd'T'HHmmss'Z'";
  static const _encoder = 'xz';

  static Future<void> build(String minAppVersion) async {
    final isarFile = File(ProjectPath.appIsarPath);
    if (!await isarFile.exists()) throw Exception('App isar file not found');

    final now = DateTime.now().toUtc();
    final createdAt = DateFormat(_dateFormat).format(now);
    final outName = 'UpBusHK-DB_$createdAt.xz'; //todo
    final outPath = join(ProjectPath.outputDir.path, outName);

    final meta = Meta(minAppVersion: minAppVersion, dataTimestamp: now);
    await isar.writeTxn(() => isar.metas.put(meta));
    await isar.close();

    // Ensured all isar writes completed
    await Future.delayed(Duration(milliseconds: 500));

    final hasXz = await _hasXz();
    if (!hasXz) throw ('Encoder \'${_encoder}\' not installed');

    final result = await Benchmark.executeAsync(
      'Compressing',
      () => Process.run(_encoder, ['-9', '-k', ProjectPath.appIsarPath]),
    );
    if (result.exitCode != 0) throw Exception('Failed:\n${result.stderr}');

    // Rename/move the output
    final compressedPath = '${ProjectPath.appIsarPath}.xz';
    await File(compressedPath).rename(outPath);

    final valid = await _validate(outPath, now);
    valid ? print('Validated: $outPath') : print('Compressed file corrupted');
  }

  static Future<bool> _hasXz() async {
    try {
      final result = await Process.run(_encoder, ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _validate(String path, DateTime dataTimestamp) async {
    const temp = 'temp';
    final xzFile = File(path);
    final inputBytes = await xzFile.readAsBytes();
    final decodedBytes = Benchmark.execute(
      'Decompressing',
      () => XZDecoder().decodeBytes(inputBytes),
    );

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
    final meta = await tempIsar.metas.where().findFirst();
    final valid = meta?.dataTimestamp == dataTimestamp;

    // Clean up
    await tempIsar.close(deleteFromDisk: true);
    final lock = await File(join(ProjectPath.outputDir.path, '$temp.isar-lck'));
    if (await lock.exists()) await lock.delete();

    return valid;
  }
}
