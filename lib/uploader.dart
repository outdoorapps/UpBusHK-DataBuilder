import 'dart:convert';
import 'dart:io';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:path/path.dart';
import 'package:up_bus_hk_core/firebase/database_info.dart';
import 'package:up_bus_hk_core/firebase/firebase_path.dart';
import 'package:up_bus_hk_data_builder/files/project_path.dart';
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
    final databaseFilename = lines.last;

    final parts = databaseFilename.split('_');
    final minAppVersion = Version.parse(parts[1].replaceAll('v', ''));
    final timestamp = DateTime.parse(parts[2].replaceAll('.tar.xz', ''));

    // 1. Upload database file
    final databaseFile = File(
      join(ProjectPath.outputDir.path, databaseFilename),
    );
    // final success = await _upload(databaseFile);
    // if (!success) throw Exception('Failed to upload database file');

    // 2. Register database version
    final ref = firebase.database().ref(FirebasePath.databaseInfo);
    final databaseInfo = DatabaseInfo(
      timestamp: timestamp,
      minAppVersion: minAppVersion,
      checksum: checksum,
    );
    ref.set(databaseInfo.toMap());
    // 3. Remove old database file
  }

  // static Future<bool> _upload(App firebase, File databaseFile) async {
  //   final uploadRef = firebase.storage().ref(basename(databaseFile.path));
  //   final bytes = await databaseFile.readAsBytes();
  //   bool success = false;
  //   try {
  //     await uploadRef.putData(bytes).snapshotEvents.listen((taskSnapshot) {
  //       switch (taskSnapshot.state) {
  //         case TaskState.running:
  //           print('Uploading ${taskSnapshot.bytesTransferred} bytes');
  //           break;
  //         case TaskState.paused:
  //           break;
  //         case TaskState.success:
  //           success = true;
  //           break;
  //         case TaskState.canceled:
  //           break;
  //         case TaskState.error:
  //           break;
  //       }
  //     });
  //   } on FirebaseException catch (e) {
  //     print(e);
  //   }
  //   return success;
  // }
}

void main() {}
