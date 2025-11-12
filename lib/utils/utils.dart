import 'package:opencc/opencc.dart';

class Utils {
  static final zhT2S = ZhConverter('t2d');

  static int nullableCompare<T extends Comparable>(T? a, T? b) {
    if (a != null && b != null) {
      return a.compareTo(b);
    } else if (a == null) {
      return 1;
    } else if (b == null) {
      return -1;
    } else {
      return 0;
    }
  }
}
