import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/isar/models/meta.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';

import '../isar/isar_manager.dart';

class XzBuilder {
  static const _dateFormat = "yyyyMMdd'T'HHmmss'Z'";
  static const _encoder = 'xz';

  /// Build the compressed database file and return the checksum
  static Future<String> build(String minAppVersion) async {
    final isarFile = File(ProjectPath.appIsarPath);
    if (!await isarFile.exists()) throw Exception('App isar file not found');

    final now = DateTime.now().toUtc();
    final createdAt = DateFormat(_dateFormat).format(now);
    final outName = 'UpBusHK_v${minAppVersion}_$createdAt.xz';
    final outPath = join(ProjectPath.outputDir.path, outName);

    final meta = Meta(minAppVersion: minAppVersion, dataTimestamp: now);
    await isar.writeTxn(() => isar.metas.put(meta));
    await isar.close();

    // Ensured all isar writes completed
    await Future.delayed(Duration(milliseconds: 500));

    final hasXz = await _hasXz();
    if (!hasXz) throw ('Encoder \'${_encoder}\' not installed');

    final bytes = await isarFile.readAsBytes();
    final checksum = sha256.convert(bytes).toString();
    final result = await Benchmark.executeAsync(
      'Compressing',
      () => Process.run(_encoder, ['-9', '-k', ProjectPath.appIsarPath]),
    );
    if (result.exitCode != 0) throw Exception('Failed:\n${result.stderr}');

    // Rename/move the output
    final compressedPath = '${ProjectPath.appIsarPath}.xz';
    await File(compressedPath).rename(outPath);

    final valid = await _validate(outPath, checksum);
    valid ? print('Validated: $outPath') : print('Compressed file corrupted');

    final checksumFile = File(join(ProjectPath.outputDir.path, 'checksum.txt'));
    await checksumFile.writeAsString('${checksum.trim()}\n$outName');

    return valid? checksum : '';
  }

  static Future<bool> _hasXz() async {
    try {
      final result = await Process.run(_encoder, ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _validate(String path, String expectedCheckSum) async {
    final inputBytes = await File(path).readAsBytes();
    final decodedBytes = Benchmark.execute(
      'Decompressing',
      () => XZDecoder().decodeBytes(inputBytes),
    );
    final checksum = sha256.convert(decodedBytes).toString();
    return checksum == expectedCheckSum;
  }
}
