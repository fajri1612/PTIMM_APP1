import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KeuanganService {
  static const String boxName = 'transaksiBox';
  static Box get _box => Hive.box(boxName);

  // 🔥 Notifier untuk progress sync
  static final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  // Listenable untuk auto-refresh UI
  static ValueListenable<Box> listenable() => _box.listenable();

  // =============================
  // Tambah transaksi (offline-first)
  // =============================
  static Future<void> addTransaksi({
    required String jenis,
    required String namaPT,
    required String deskripsi,
    required double jumlah,
    required DateTime tanggal,
    required String noPO,
  }) async {
    final data = {
      'jenis': jenis,
      'namaPT': namaPT,
      'deskripsi': deskripsi,
      'noPO': noPO,
      'jumlah': jumlah,
      'tanggal': tanggal.toIso8601String(),
      'unsynced': true,
    };

    final index = await _box.add(data);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("keuangan")
            .add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final updated = Map<String, dynamic>.from(_box.getAt(index));
        updated['unsynced'] = false;
        updated['remoteId'] = doc.id;
        await _box.putAt(index, updated);
      }
    } catch (e) {
      debugPrint("Gagal upload ke Firestore: $e");
    }
  }

  // =============================
  // Update transaksi
  // =============================
  static Future<void> updateTransaksi(int index, Map<String, dynamic> newData) async {
    final existing = Map<String, dynamic>.from(_box.getAt(index));
    final updated = {
      ...existing,
      ...newData,
      'unsynced': true, // tandai perlu sync
    };

    await _box.putAt(index, updated);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && updated['remoteId'] != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("keuangan")
            .doc(updated['remoteId'])
            .update({
          'jenis': updated['jenis'],
          'namaPT': updated['namaPT'],
          'deskripsi': updated['deskripsi'],
          'noPO': updated['noPO'],
          'jumlah': updated['jumlah'],
          'tanggal': updated['tanggal'],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        updated['unsynced'] = false;
        await _box.putAt(index, updated);
      }
    } catch (e) {
      debugPrint("Gagal update Firestore: $e");
    }
  }

  // =============================
  // Hapus transaksi
  // =============================
  static Future<void> deleteTransaksi(int index) async {
    final data = Map<String, dynamic>.from(_box.getAt(index));

    await _box.deleteAt(index);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && data['remoteId'] != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("keuangan")
            .doc(data['remoteId'])
            .delete();
      }
    } catch (e) {
      debugPrint("Gagal hapus Firestore: $e");
    }
  }

  // =============================
  // Sinkronisasi offline → online
  // =============================
  static Future<void> syncOfflineData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isSyncing.value = true;

    for (int i = 0; i < _box.length; i++) {
      final raw = _box.getAt(i);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);

      if (data['unsynced'] == true) {
        try {
          if (data['remoteId'] != null) {
            // 🔄 Update ke Firestore
            await FirebaseFirestore.instance
                .collection("users")
                .doc(user.uid)
                .collection("keuangan")
                .doc(data['remoteId'])
                .set({
              'jenis': data['jenis'],
              'namaPT': data['namaPT'],
              'deskripsi': data['deskripsi'],
              'noPO': data['noPO'],
              'jumlah': data['jumlah'],
              'tanggal': data['tanggal'],
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else {
            // ➕ Tambah baru ke Firestore
            final doc = await FirebaseFirestore.instance
                .collection("users")
                .doc(user.uid)
                .collection("keuangan")
                .add({
              'jenis': data['jenis'],
              'namaPT': data['namaPT'],
              'deskripsi': data['deskripsi'],
              'noPO': data['noPO'],
              'jumlah': data['jumlah'],
              'tanggal': data['tanggal'],
              'createdAt': FieldValue.serverTimestamp(),
            });
            data['remoteId'] = doc.id;
          }

          data['unsynced'] = false;
          await _box.putAt(i, data);
        } catch (e) {
          debugPrint("Sync gagal index $i: $e");
        }
      }
    }

    isSyncing.value = false;
  }

  // =============================
  // Ambil semua transaksi
  // =============================
  static List<Map<String, dynamic>> getAllTransaksi() {
    return List.generate(_box.length, (i) {
      final raw = _box.getAt(i);
      if (raw is! Map) return {};
      final map = Map<String, dynamic>.from(raw);

      return {
        'id': i,
        'jenis': map['jenis'] ?? 'Pemasukan',
        'namaPT': map['namaPT'] ?? 'Tanpa Nama',
        'deskripsi': map['deskripsi'] ?? '-',
        'noPO': map['noPO'] ?? '-',
        'jumlah': (map['jumlah'] is num ? map['jumlah'] : 0).toDouble(),
        'tanggal': DateTime.tryParse(map['tanggal'].toString()) ?? DateTime.now(),
        'unsynced': map['unsynced'] ?? false,
        'remoteId': map['remoteId'],
      };
    });
  }

  // =============================
  // Utility
  // =============================
  static double getTotalPemasukan() => getAllTransaksi()
      .where((t) => t['jenis'] == 'Pemasukan')
      .fold(0.0, (sum, t) => sum + (t['jumlah'] ?? 0.0));

  static double getTotalPengeluaran() => getAllTransaksi()
      .where((t) => t['jenis'] == 'Pengeluaran')
      .fold(0.0, (sum, t) => sum + (t['jumlah'] ?? 0.0));

  static double getSaldo() => getTotalPemasukan() - getTotalPengeluaran();
}
