import 'dart:convert';
import 'dart:typed_data';

class ImageService {
  /// Convert Uint8List (gambar) ke Base64 String
  static String toBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  /// Convert Base64 String ke Uint8List (untuk ditampilkan)
  static Uint8List fromBase64(String base64String) {
    return base64Decode(base64String);
  }
}
