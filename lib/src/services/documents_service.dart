import 'dart:typed_data'; // ✅ dipakai untuk Web (preview & upload via bytes)
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// DocumentService
/// - Simpan metadata dokumen ke Hive (offline)
/// - Support Web preview via bytes
/// - Sync otomatis ke Firestore (online, metadata only)
/// - Tidak menggunakan Firebase Storage
class DocumentService {
  static const String boxName = "documentBox";

  static Box get _box => Hive.box(boxName);

  /// Untuk auto-refresh UI dengan ValueListenableBuilder
  static ValueListenable<Box> listenable() => _box.listenable();

  /// Tambah dokumen
  static Future<void> addDocument({
    required String judul,
    required String kategori,
    String? path, // path lokal (Mobile/Desktop)
    Uint8List? bytes, // dokumen bytes (Web)
    required bool manual,
    String? content,
    String? signaturePath, // tetap lokal, tidak sync
    String? penandatangan,
  }) async {
    final tanggal = DateTime.now().toIso8601String().split("T")[0];

    final data = {
      "judul": judul,
      "kategori": kategori,
      "tanggal": tanggal,
      "path": path ?? "",
      "bytes": bytes, // ✅ untuk Web
      "manual": manual,
      "content": content,
      "signaturePath": signaturePath,
      "penandatangan": penandatangan ?? "Direktur",
      "unsynced": true, // default merah → hijau jika sync sukses
      "remoteId": null,
      "storage": false, // tidak ada upload storage
    };

    final index = await _box.add(data);

    // langsung coba sync ke cloud
    await _trySyncToCloud(index, data);
  }

  /// Sinkronisasi semua dokumen offline → cloud
  static Future<void> syncOfflineData({bool forceResync = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (int i = 0; i < _box.length; i++) {
      final raw = _box.getAt(i);
      if (raw == null) continue;

      final data = Map<String, dynamic>.from(raw);
      if (forceResync || data["unsynced"] == true) {
        await _trySyncToCloud(i, data);
      }
    }
  }

  /// Sync metadata ke Firestore (tanpa file storage)
  static Future<void> _trySyncToCloud(int index, Map<String, dynamic> data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Skip jika sudah sync
      if (data["remoteId"] != null && data["unsynced"] == false) return;

      final docRef = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("documents")
          .add({
        "judul": data["judul"],
        "kategori": data["kategori"],
        "tanggal": data["tanggal"],
        "manual": data["manual"],
        "content": data["content"],
        "penandatangan": data["penandatangan"],
        "signaturePath": null, // tidak sync ke cloud
        "createdAt": FieldValue.serverTimestamp(),
      });

      // update Hive → tandai synced
      final updated = Map<String, dynamic>.from(data)
        ..["unsynced"] = false
        ..["remoteId"] = docRef.id
        ..["storage"] = false;

      await _box.putAt(index, updated);

      debugPrint("✅ Sync sukses: ${data["judul"]}");
    } catch (e) {
      debugPrint("❌ Sync gagal index $index: $e");
    }
  }

  /// Ambil semua dokumen (untuk UI / preview)
  static List<Map<String, dynamic>> getAllDocuments() {
    return _box.values.map<Map<String, dynamic>>((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return {
        "judul": map["judul"] ?? "-",
        "kategori": map["kategori"] ?? "-",
        "tanggal": map["tanggal"] ?? DateTime.now().toIso8601String(),
        "path": map["path"] ?? "",
        "bytes": map["bytes"], // ✅ untuk Web preview
        "manual": map["manual"] ?? false,
        "content": map["content"],
        "signaturePath": map["signaturePath"],
        "penandatangan": map["penandatangan"] ?? "Direktur",
        "unsynced": map["unsynced"] ?? true,
        "remoteId": map["remoteId"],
        "storage": map["storage"] ?? false,
      };
    }).toList();
  }

  /// Ambil dokumen berdasarkan index
  static Map<String, dynamic>? getDocumentAt(int index) {
    if (index < 0 || index >= _box.length) return null;
    final raw = _box.getAt(index);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Hapus dokumen
  static Future<void> deleteDocument(int index) async {
    await _box.deleteAt(index);
  }

  /// Update metadata lokal
  static Future<void> updateDocument(int index, Map<String, dynamic> data) async {
    await _box.putAt(index, Map<String, dynamic>.from(data));
  }

  /// Preview dokumen (otomatis pilih path / bytes sesuai platform)
  static Uint8List? getDocumentBytes(int index) {
    final doc = getDocumentAt(index);
    if (doc == null) return null;

    if (kIsWeb) {
      return doc["bytes"] as Uint8List?;
    } else {
      final path = doc["path"] as String?;
      if (path != null && path.isNotEmpty) {
        // 🔹 Di Mobile/Desktop: bisa baca file secara langsung dengan File(path).readAsBytes()
        // Tapi di sini dikembalikan null agar lebih fleksibel
        return null;
      }
    }
    return null;
  }
}
