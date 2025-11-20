import 'package:proj4dart/proj4dart.dart';
import 'package:up_bus_hk_core/isar/models/lat_lng.dart';

class Crs2326 {
  static final _epsg2326 = Projection.add(
    'EPSG:2326',
    '+proj=tmerc +lat_0=22.31213333333333 '
        '+lon_0=114.1785555555556 +k=1 +x_0=836694.05 +y_0=819069.8 '
        '+a=6378388 +b=6356911.946127946 '
        '+towgs84=-162.619,-276.959,-161.764,-1.043,-2.716,-1.704,0 '
        '+units=m +no_defs',
  );

  static final _wgs84 = Projection.get('EPSG:4326');

  /// Convert from EPSG:2326 (HK1980) to EPSG:4326 (WGS84) coordinates
  static List<double> convert(double x2326, double y2326) {
    final p = _epsg2326.transform(_wgs84!, Point(x: x2326, y: y2326));
    return [p.y, p.x]; // y is latitude, x is longitude
  }
}
