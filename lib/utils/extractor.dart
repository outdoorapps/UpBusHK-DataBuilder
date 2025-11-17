import 'package:archive/archive.dart';
import 'package:path/path.dart';

class Extractor {
  static Future<void> extractZipFile(String path, String outputDir) async {
    final inputStream = InputFileStream(path);
    final archive = ZipDecoder().decodeStream(inputStream);
    for (final file in archive) {
      if (file.isFile) {
        final out = OutputFileStream(join(outputDir, file.name));
        file.writeContent(out);
        await out.close();
      }
    }
  }
}
