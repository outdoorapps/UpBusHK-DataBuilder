import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/firebase/database_info.dart';
import 'package:up_bus_hk_core/firebase/firebase_paths.dart';
import 'package:up_bus_hk_data_builder/files/project_paths.dart';
import 'package:version/version.dart';

class Uploader {
  static const _credentials =
      'secrets/upbushk-firebase-adminsdk-3obkp-773ff4b827.json';

  Future<void> upload() async {
    final checksumFile = File(join(ProjectPath.outputDir.path, 'checksum.txt'));
    final lines = await checksumFile.readAsLines(encoding: utf8);
    final checksum = lines.first;
    final databaseFilename = lines.last;

    // final serviceAccount = jsonDecode(await File(serviceAccountPath).readAsString());
    // final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccount);

    // 1. Upload database file
    final databaseFile = File(
      join(ProjectPath.outputDir.path, databaseFilename),
    );
    final success = await _upload(databaseFile);
    if (!success) throw Exception('Failed to upload database file');

    // 2. Register database version
    final parts = databaseFilename.split('_');
    final minAppVersion = Version.parse(parts[1].replaceAll('v', ''));
    final timestamp = DateTime.parse(parts[2].replaceAll('.tar.xz', ''));

    final firebaseDatabase = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: FirebasePath.realtimeDatabase,
    );
    final ref = firebaseDatabase.ref(FirebasePath.databaseInfo);
    final databaseInfo = DatabaseInfo(
      timestamp: timestamp,
      minAppVersion: minAppVersion,
      checksum: checksum,
    );
    ref.set(databaseInfo.toMap());

    // 3. Remove old database file
  }

  Future<bool> _upload(File databaseFile) async {
    final firebaseStorage = FirebaseStorage.instanceFor(
      app: Firebase.app(),
      bucket: FirebasePath.storge,
    );
    final uploadRef = firebaseStorage.ref(basename(databaseFile.path));
    bool success = false;
    try {
      await uploadRef.putFile(databaseFile).snapshotEvents.listen((
        taskSnapshot,
      ) {
        switch (taskSnapshot.state) {
          case TaskState.running:
            print('Uploading ${taskSnapshot.bytesTransferred} bytes');
            break;
          case TaskState.paused:
            break;
          case TaskState.success:
            success = true;
            break;
          case TaskState.canceled:
            break;
          case TaskState.error:
            break;
        }
      });
    } on FirebaseException catch (e) {
      print(e);
    }
    return success;
  }
}

void main() {}
