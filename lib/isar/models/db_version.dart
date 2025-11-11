import 'package:isar_community/isar.dart';

part '../../generated/isar/models/db_version.g.dart';

/// Database creation time in UTC of the downloaded xz file
@Collection()
class DBVersion {
  Id id = 1;
  String created;

  DBVersion(this.created);
}
