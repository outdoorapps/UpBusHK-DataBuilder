import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/extension/meta_x.dart';
import 'package:up_bus_hk_core/isar/models/meta.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';

import '../isar/isar_manager.dart';

class ArchiveBuilder {
  static const _encoder = 'xz';

  /// Build the compressed database file and return the checksum
  static Future<String> build(String minAppVersion) async {
    final isarFile = File(ProjectPath.appIsarPath);
    if (!await isarFile.exists()) throw Exception('App isar file not found');

    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.timestamp().millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: true,
    ); // Round down to the nearest seconds
    final createdAt = MetaX.dataVersionFormat.format(now);
    final filename = 'UpBusHK_v${minAppVersion}_$createdAt';
    final outPath = join(ProjectPath.outputDir.path, '$filename.tar.xz');

    final meta = Meta(minAppVersion: minAppVersion, dataTimestamp: now);
    await isar.writeTxn(() => isar.metas.put(meta));
    await isar.close();

    // Ensured all isar writes completed
    await Future.delayed(Duration(milliseconds: 500));

    final hasXz = await _hasXz();
    if (!hasXz) throw ('Encoder \'${_encoder}\' not installed');

    // Get checksum
    final bytes = await isarFile.readAsBytes();
    final checksum = sha256.convert(bytes).toString();

    // 1. Create TAR
    final tarPath = join(ProjectPath.outputDir.path, '$filename.tar');
    final length = await isarFile.length();

    final output = OutputFileStream(tarPath);
    final archive = Archive()
      ..add(ArchiveFile('$filename.isar', length, bytes));
    TarEncoder().encode(archive, output: output);

    // 2. Create XZ
    final result = await Benchmark.executeAsync(
      'Compressing',
      () => Process.run(_encoder, ['-9', '-e', tarPath]),
    );
    if (result.exitCode != 0) throw Exception('Failed:\n${result.stderr}');

    final valid = await _validate(outPath, checksum);
    valid ? print('Validated: $outPath') : print('Compressed file corrupted');

    final checksumFile = File(join(ProjectPath.outputDir.path, 'checksum.txt'));
    await checksumFile.writeAsString('${checksum.trim()}\n$filename');

    return valid ? checksum : '';
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
    final decodedBytes = Benchmark.execute('Decompressing', () {
      final tarBytes = XZDecoder().decodeBytes(inputBytes);
      final archive = TarDecoder().decodeBytes(tarBytes);
      return archive.first.content;
    });
    final checksum = sha256.convert(decodedBytes).toString();
    return checksum == expectedCheckSum;
  }
}
