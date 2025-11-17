import 'package:latlong2/latlong.dart' as latlong2;
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';

extension LatLngX on LatLng {
  latlong2.LatLng toLatLong() => latlong2.LatLng(lat, long);
}
