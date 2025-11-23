import 'package:proj4dart/proj4dart.dart';
import 'package:up_bus_hk_core/utils/utils.dart';
import 'package:up_bus_hk_data_builder/network/web_services.dart';

class Crs2326 {
  static Future<void> init() async {
    final epsg2326Proj4 = await WebServices.epsg.getProj4(2326);
    Projection.add('EPSG:2326', epsg2326Proj4);
  }

  static final _wgs84 = Projection.get('EPSG:4326');

  /// Convert from EPSG:2326 (HK1980) to EPSG:4326 (WGS84) coordinates
  static List<double> convert(double x2326, double y2326) {
    final projection = Projection.get('EPSG:2326');
    if (projection == null) throw Exception('Projection not found');

    final p = projection.transform(_wgs84!, Point(x: x2326, y: y2326));

    // y is latitude, x is longitude
    return [Utils.roundLatLng(p.y), Utils.roundLatLng(p.x)];
  }
}
