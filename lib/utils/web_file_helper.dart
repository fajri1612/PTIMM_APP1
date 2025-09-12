// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class FileHelper {
  /// Buka file dari URL (contoh: https://... atau base64 string yang sudah diubah jadi blob URL)
  static void openFile(String url) {
    html.window.open(url, "_blank"); // ✅ hapus .focus()
  }

  /// Buka file dari bytes (misalnya hasil upload PDF)
  static void openBytes(Uint8List bytes, {String fileName = "preview.pdf", String mimeType = "application/pdf"}) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.window.open(url, "_blank"); // ✅ hapus .focus()

    // revoke biar gak leak memory
    Future.delayed(const Duration(seconds: 5), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
