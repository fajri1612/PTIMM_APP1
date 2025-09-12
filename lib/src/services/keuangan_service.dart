import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KeuanganService {
  static const String boxName = 'transaksiBox';
  static Box get _box => Hive.box('transaksiBox');

  // 🔥 Notifier untuk progress sync
  static final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  // Listenable untuk auto-refresh UI
  static ValueListenable<Box> listenable() {
    return _box.listenable();
  }

  // Tambah transaksi baru (offline-first)
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
      'unsynced': true, // default: offline dulu
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
          'jenis': jenis,
          'namaPT': namaPT,
          'deskripsi': deskripsi,
          'noPO': noPO,
          'jumlah': jumlah,
          'tanggal': tanggal.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // update Hive -> sudah tersinkron
        final updated = Map<String, dynamic>.from(_box.getAt(index));
        updated['unsynced'] = false;
        updated['remoteId'] = doc.id;
        await _box.putAt(index, updated);
      }
    } catch (e) {
      debugPrint("Gagal upload ke Firestore, simpan offline: $e");
    }
  }

  // Sinkronisasi otomatis (push unsynced -> Firestore)
  static Future<void> syncOfflineData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isSyncing.value = true; // 🚀 mulai sync

    for (int i = 0; i < _box.length; i++) {
      final data = _box.getAt(i);
      if (data is Map && data['unsynced'] == true) {
        try {
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

          // update status di Hive
          final updated = Map<String, dynamic>.from(data);
          updated['unsynced'] = false;
          updated['remoteId'] = doc.id;
          await _box.putAt(i, updated);
        } catch (e) {
          debugPrint("Sync gagal untuk index $i: $e");
        }
      }
    }

    isSyncing.value = false; // ✅ selesai sync
  }

  // Ambil semua transaksi dari Hive
  static List<Map<String, dynamic>> getAllTransaksi() {
    return _box.values.map<Map<String, dynamic>>((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return {
        'jenis': map['jenis'] ?? 'Pemasukan',
        'namaPT': map['namaPT'] ?? 'Tanpa Nama',
        'deskripsi': map['deskripsi'] ?? '-',
        'noPO': map['noPO'] ?? '-',
        'jumlah': (map['jumlah'] is num ? map['jumlah'] : 0).toDouble(),
        'tanggal': DateTime.tryParse(map['tanggal'].toString()) ?? DateTime.now(),
        'unsynced': map['unsynced'] ?? false,
        'remoteId': map['remoteId'],
      };
    }).toList();
  }

  // Hitung total pemasukan
  static double getTotalPemasukan() {
    return getAllTransaksi()
        .where((t) => t['jenis'] == 'Pemasukan')
        .fold(0.0, (sum, t) => sum + (t['jumlah'] ?? 0.0));
  }

  // Hitung total pengeluaran
  static double getTotalPengeluaran() {
    return getAllTransaksi()
        .where((t) => t['jenis'] == 'Pengeluaran')
        .fold(0.0, (sum, t) => sum + (t['jumlah'] ?? 0.0));
  }

  // Hitung saldo
  static double getSaldo() {
    return getTotalPemasukan() - getTotalPengeluaran();
  }

  // Hapus transaksi berdasarkan index
  static Future<void> deleteTransaksi(int index) async {
    await _box.deleteAt(index);
  }

  // Update transaksi
  static Future<void> updateTransaksi(
      int index, Map<String, dynamic> data) async {
    await _box.putAt(index, data);
  }
}
