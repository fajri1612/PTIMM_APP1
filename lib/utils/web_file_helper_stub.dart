import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FileHelper {
  /// Buka file dari path lokal
  static Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }

  /// Buka file dari bytes (disimpan dulu ke temporary folder)
  static Future<void> openBytes(Uint8List bytes, {String fileName = "preview.pdf"}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }
}
