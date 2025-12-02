import 'dart:convert';
import 'dart:io';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/firebase/database_info.dart';
import 'package:up_bus_hk_core/firebase/firebase_path.dart';
import 'package:up_bus_hk_core/format/archive_format.dart';
import 'package:up_bus_hk_data_builder/files/project_path.dart';
import 'package:up_bus_hk_data_builder/utils/benchmark.dart';
import 'package:version/version.dart';

class Uploader {
  static Future<void> upload() async {
    // Setup service account credentials
    final credential = Credentials.applicationDefault();
    if (credential == null)
      throw Exception('service-account.json missing at project root');

    final firebase = FirebaseAdmin.instance.initializeApp(
      AppOptions(
        credential: credential,
        storageBucket: FirebasePath.storge,
        databaseUrl: FirebasePath.realtimeDatabase,
      ),
    );

    // Setup params
    final checksumFile = File(join(ProjectPath.outputDir.path, 'checksum.txt'));
    final lines = await checksumFile.readAsLines(encoding: utf8);
    final checksum = lines.first;
    final databaseFilename = '${lines.last}${ArchiveFormat.archiveExtension}';
    final databaseFile = File(
      join(ProjectPath.outputDir.path, databaseFilename),
    );
    final minAppVersion = Version.parse(
      ArchiveFormat.versionRegex.firstMatch(databaseFilename)?.group(1) ?? '',
    );
    final timestamp = DateTime.parse(
      ArchiveFormat.timeStampRegex.firstMatch(databaseFilename)?.group(1) ?? '',
    );
    final databaseInfo = DatabaseInfo(
      timestamp: timestamp,
      minAppVersion: minAppVersion,
      checksum: checksum,
    );
    try {
      // 1. Upload database file
      final uploaded = await Benchmark.executeAsync(
        'Uploading database file',
        () => _upload(firebase, databaseFile),
      );
      if (!uploaded) throw Exception('Failed to upload database file');

      // 2. Register database version
      final registered = await Benchmark.executeAsync(
        'Registering database change',
        () => _register(firebase, databaseInfo),
      );
      if (!registered) throw Exception('Failed to register database change');

      // 3. Remove old database file
      final cleanedUp = await Benchmark.executeAsync(
        'Deleting old database files',
        () => _deleteOldFiles(firebase, databaseFilename),
      );
      if (!cleanedUp) throw Exception('Failed to delete old database files');
    } catch (e, st) {
      print('$e\n$st');
    } finally {
      firebase.delete(); // Terminate properly
    }
  }

  static Future<bool> _upload(App firebase, File databaseFile) async {
    try {
      final bytes = await databaseFile.readAsBytes();
      await firebase.storage().bucket().writeBytes(
        basename(databaseFile.path),
        bytes,
      );
    } catch (e, st) {
      print('$e\n$st');
      return false;
    }
    return true;
  }

  static Future<bool> _register(App firebase, DatabaseInfo databaseInfo) async {
    try {
      final ref = firebase.database().ref(FirebasePath.databaseInfo);
      await ref.set(databaseInfo.toMap());
    } catch (e, st) {
      print('$e\n$st');
      return false;
    }
    return true;
  }

  static Future<bool> _deleteOldFiles(App firebase, String keepFile) async {
    try {
      final bucket = firebase.storage().bucket();
      final filesToDelete = <String>{};
      await for (final entry in bucket.list()) {
        if (entry.isDirectory) continue;

        final name = entry.name;
        if (name == keepFile || !ArchiveFormat.archiveRegex.hasMatch(name))
          continue;

        filesToDelete.add(name);
      }
      await Future.wait(filesToDelete.map((name) => bucket.delete(name)));

      filesToDelete.forEach((e) => print('Removed: $e'));
    } catch (e, st) {
      print('$e\n$st');
      return false;
    }
    return true;
  }
}
