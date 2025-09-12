import 'package:flutter/material.dart';
import '../src/services/keuangan_service.dart';
import 'main_layout.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String backupFolderPath = '';

  @override
  void initState() {
    super.initState();
    _initBackupFolder();
  }

  // 🔹 Initialize backup folder path
  Future<void> _initBackupFolder() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/hive_backup');
    setState(() {
      backupFolderPath = backupDir.path;
    });
  }

  // 🔹 Helper format Rupiah
  String formatRupiah(num number, {bool withDecimal = false}) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: withDecimal ? 2 : 0,
    ).format(number);
  }

  // 🔹 Fungsi Backup Hive
  Future<void> backupHive() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/hive_backup');

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final boxes = ['documentBox', 'keuanganBox'];

      for (var boxName in boxes) {
        final boxFile = File('${appDir.path}/$boxName.hive');
        final backupFile = File('${backupDir.path}/$boxName.hive.bak');

        if (await boxFile.exists()) {
          await boxFile.copy(backupFile.path);
          debugPrint('✅ Backup $boxName berhasil: ${backupFile.path}');
        } else {
          debugPrint('⚠️ Box $boxName tidak ditemukan');
        }
      }

      setState(() {
        backupFolderPath = backupDir.path;
      });
    } catch (e) {
      debugPrint('❌ Backup gagal: $e');
    }
  }

  // 🔹 Fungsi Restore Hive
  Future<void> restoreHive() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/hive_backup');

      if (!await backupDir.exists()) {
        debugPrint('⚠️ Folder backup tidak ditemukan');
        return;
      }

      final boxes = ['documentBox', 'keuanganBox'];

      for (var boxName in boxes) {
        final backupFile = File('${backupDir.path}/$boxName.hive.bak');
        final boxFile = File('${appDir.path}/$boxName.hive');

        if (await backupFile.exists()) {
          await backupFile.copy(boxFile.path);
          debugPrint('✅ Restore $boxName berhasil');
        } else {
          debugPrint('⚠️ Backup file $boxName tidak ditemukan');
        }
      }

      // Re-open Hive box jika belum terbuka
      for (var boxName in boxes) {
        if (!Hive.isBoxOpen(boxName)) {
          await Hive.openBox(boxName);
        }
      }
    } catch (e) {
      debugPrint('❌ Restore gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isVerySmall = size.width < 360;

    return MainLayout(
      currentPage: '/dashboard',
      title: "Dashboard",
      collapsible: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Header
            const Text(
              "Selamat Datang di PT INTI MAS MULIA",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Ringkasan Keuangan
            const Text(
              "Ringkasan Keuangan",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            ValueListenableBuilder(
              valueListenable: KeuanganService.listenable(),
              builder: (context, box, _) {
                final totalPemasukan = KeuanganService.getTotalPemasukan();
                final totalPengeluaran = KeuanganService.getTotalPengeluaran();
                final saldo = KeuanganService.getSaldo();

                final summaryCards = [
                  _buildSummaryCard(
                      "Pemasukan", formatRupiah(totalPemasukan), Colors.green),
                  _buildSummaryCard("Pengeluaran",
                      formatRupiah(totalPengeluaran), Colors.red),
                  _buildSummaryCard("Saldo", formatRupiah(saldo), Colors.blue),
                ];

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: summaryCards
                      .map((card) => SizedBox(
                            width: size.width / (isVerySmall ? 1 : 3) - 20,
                            child: card,
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 28),

            // 🔹 Akses Cepat
            const Text(
              "Akses Cepat",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: isVerySmall ? 1 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio:
                  size.width < 360 ? 1.0 : (size.width < 600 ? 1.2 : 1.6),
              children: [
                _buildQuickAccessCard(
                  icon: Icons.bar_chart,
                  title: "Modul Keuangan",
                  subtitle: "Lihat & kelola transaksi keuangan.",
                  onTap: () => Navigator.pushNamed(context, '/keuangan'),
                ),
                _buildQuickAccessCard(
                  icon: Icons.folder,
                  title: "Dokumen Perusahaan",
                  subtitle: "Upload & arsip dokumen penting.",
                  onTap: () => Navigator.pushNamed(context, '/documents'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔹 Tombol Backup & Restore
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.backup),
                    label: const Text('Backup Data'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                    ),
                    onPressed: () async {
                      await backupHive();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Backup berhasil!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Data'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                    ),
                    onPressed: () async {
                      await restoreHive();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Restore berhasil!')),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 🔹 Tampilkan lokasi folder backup
            if (backupFolderPath.isNotEmpty)
              Text(
                "Folder Backup: $backupFolderPath",
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  // 🔹 Summary Card
  static Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 🔹 Quick Access Card
  static Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
