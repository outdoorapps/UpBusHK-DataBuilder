class BuilderUtils {
  static String formatDuration(Duration d, {bool showMs = true}) {
    return d.inSeconds < 60
        ? '${showMs ? (d.inMilliseconds / 1000) : d.inSeconds}s'
        : '${d.inMinutes} min ${d.inSeconds % 60} s';
  }
}
