import 'dart:math';

class RamerDouglasPeucker {
  /// Simplifies a WGS84 polyline using epsilon in **meters**.
  ///
  /// Input format: [ [lat, lng], [lat, lng], ... ]
  static List<List<double>> simplifyWGS84(
    List<List<double>> coordinates, {
    required double epsilonInMeters,
  }) {
    if (coordinates.length < 3) return coordinates;

    // Convert all lat/lng into Web Mercator meters
    final mercator = coordinates.map(_projectWebMercator).toList();

    // Run meter-based RDP on projected points
    final simplifiedMercator = _rdp(mercator, epsilonInMeters);

    // Convert back into lat/lng
    return simplifiedMercator.map(_unprojectWebMercator).toList();
  }

  /// Convert lat/lng into Web Mercator meters
  static _Point _projectWebMercator(List<double> latLng) {
    final lat = latLng[0];
    final lng = latLng[1];

    const earthRadius = 6378137.0;

    final x = earthRadius * lng * pi / 180;
    final y = earthRadius * log(tan(pi / 4 + (lat * pi / 180) / 2));

    return _Point(x, y);
  }

  /// Convert Web Mercator meters back to lat/lng
  static List<double> _unprojectWebMercator(_Point p) {
    const earthRadius = 6378137.0;
    final lng = (p.x / earthRadius) * 180 / pi;
    final lat = (2 * atan(exp(p.y / earthRadius)) - pi / 2) * 180 / pi;
    return [lat, lng];
  }

  /// Standard RDP but operating in **meters** (projected space).
  static List<_Point> _rdp(List<_Point> points, double epsilon) {
    if (points.length < 3) return points;

    double dmax = 0.0;
    int index = 0;
    final end = points.length - 1;

    for (int i = 1; i < end; i++) {
      final d = _perpendicularDistance(points[i], points[0], points[end]);
      if (d > dmax) {
        dmax = d;
        index = i;
      }
    }

    if (dmax > epsilon) {
      final rec1 = _rdp(points.sublist(0, index + 1), epsilon);
      final rec2 = _rdp(points.sublist(index, points.length), epsilon);
      return [...rec1.sublist(0, rec1.length - 1), ...rec2];
    }
    return [points.first, points.last];
  }

  /// Perpendicular distance in **meters** since inputs are in projected Mercator.
  static double _perpendicularDistance(_Point p, _Point start, _Point end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;

    if (dx == 0 && dy == 0) {
      return sqrt(pow(p.x - start.x, 2) + pow(p.y - start.y, 2));
    }
    return ((dy * p.x - dx * p.y + end.x * start.y - end.y * start.x).abs()) /
        sqrt(dx * dx + dy * dy);
  }
}

/// Simple 2D point class
class _Point {
  final double x;
  final double y;

  _Point(this.x, this.y);
}
