import 'dart:math';

class RamerDouglasPeucker {
  static const double defaultEpsilon = 3; //todo 0.01 / 1000000;

  static Point _pointFromCoordinate(List<double> coord) =>
      Point(coord[1], coord[0]);

  static List<List<double>> simplify(
    List<List<double>> coordinates, {
    double epsilon = defaultEpsilon,
  }) {
    if (coordinates.length < 3) return coordinates;

    double dmax = 0.0;
    int index = 0;
    final end = coordinates.length;

    // Find point with maximum distance
    for (int i = 1; i < end - 1; i++) {
      final d = perpendicularDistance(
        _pointFromCoordinate(coordinates[i]),
        _pointFromCoordinate(coordinates[0]),
        _pointFromCoordinate(coordinates[end - 1]),
      );
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (dmax > epsilon) {
      final rec1 = simplify(
        coordinates.sublist(0, index + 1),
        epsilon: epsilon,
      );
      final rec2 = simplify(coordinates.sublist(index, end), epsilon: epsilon);

      // Combine (drop duplicate midpoint)
      return [...rec1.sublist(0, rec1.length - 1), ...rec2];
    }

    // Return endpoints
    return [coordinates.first, coordinates.last];
  }

  static double perpendicularDistance(Point p, Point start, Point end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;

    if (dx == 0 && dy == 0) {
      return (p.x - start.x).abs() + (p.y - start.y).abs();
    }

    final numerator = (dy * p.x - dx * p.y + end.x * start.y - end.y * start.x)
        .abs();
    final denominator = sqrt(dx * dx + dy * dy);

    return numerator / denominator;
  }
}

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);
}
