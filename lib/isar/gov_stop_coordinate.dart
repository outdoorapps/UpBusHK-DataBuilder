import 'package:isar_community/isar.dart';
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';

part '../generated/isar/gov_stop_coordinate.g.dart';

@collection
class GovStopCoordinate {
  Id id = Isar.autoIncrement;

  @Index()
  int stopId;
  LatLng latLng;

  GovStopCoordinate({required this.stopId, required this.latLng});
}
