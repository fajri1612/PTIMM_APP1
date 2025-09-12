import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

import '../src/services/keuangan_service.dart';
import '../ui/invoice_page.dart';
import 'main_layout.dart';

class KeuanganPage extends StatefulWidget {
  const KeuanganPage({super.key});

  @override
  State<KeuanganPage> createState() => _KeuanganPageState();
}

class _KeuanganPageState extends State<KeuanganPage> {
  final _formKey = GlobalKey<FormState>();

  final namaPTController = TextEditingController();
  final deskripsiController = TextEditingController();
  final noPOController = TextEditingController();
  final hargaController = TextEditingController();
  String selectedJenis = "Pemasukan";
  DateTime selectedDate = DateTime.now();

  bool _isSyncing = false;

  // ===== STATE FILTER =====
  String? filterJenis;
  DateTime? filterStart;
  DateTime? filterEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _syncData();
    });
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      await KeuanganService.syncOfflineData();
    } catch (e) {
      _showSnack("Gagal sinkronisasi: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    namaPTController.dispose();
    deskripsiController.dispose();
    noPOController.dispose();
    hargaController.dispose();
    super.dispose();
  }

  // ======================================
  // EXPORT PDF
  // ======================================
  Future<void> _exportPDF() async {
    try {
      final transaksi = KeuanganService.getAllTransaksi();
      if (transaksi.isEmpty) {
        _showSnack("Tidak ada data untuk diexport");
        return;
      }

      final totalPemasukan = transaksi
          .where((t) => t['jenis'] == "Pemasukan")
          .fold<double>(0.0, (sum, t) => sum + (t['jumlah'] as num).toDouble());
      final totalPengeluaran = transaksi
          .where((t) => t['jenis'] == "Pengeluaran")
          .fold<double>(0.0, (sum, t) => sum + (t['jumlah'] as num).toDouble());
      final saldo = totalPemasukan - totalPengeluaran;

      final pdf = pw.Document();

      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png'))
            .buffer
            .asUint8List(),
      );

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // HEADER
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 80, height: 80, child: pw.Image(logo)),
                    pw.SizedBox(width: 16),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("PT. INTI MAS MULIA",
                            style: pw.TextStyle(
                                fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            "GENERAL CONTRACTOR, SUPPLIER, FABRICATION MECHANICAL & ELECTRICAL",
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(
                            "Ruko Griya Laguna Mas Blok A No 09 Tembesi Batam",
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Phone: 0778 3852598 / 0813 7109 0680",
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Email: intimasmulia.pt@gmail.com",
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    )
                  ],
                ),
                pw.SizedBox(height: 24),

                pw.Center(
                  child: pw.Text("LAPORAN KEUANGAN",
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 16),

                pw.Table.fromTextArray(
                  headers: [
                    "Tanggal",
                    "Jenis",
                    "Nama PT",
                    "Deskripsi",
                    "No.PO",
                    "Harga"
                  ],
                  data: transaksi.map((t) {
                    final tanggal = t['tanggal'] is DateTime
                        ? t['tanggal']
                        : DateTime.tryParse(t['tanggal'].toString()) ??
                            DateTime.now();
                    final jumlah = t['jumlah'] is num
                        ? t['jumlah']
                        : double.tryParse(t['jumlah'].toString()) ?? 0;

                    return [
                      DateFormat("dd/MM/yyyy").format(tanggal),
                      t['jenis'] ?? '',
                      t['namaPT'] ?? '',
                      t['deskripsi'] ?? '',
                      t['noPO'] ?? '',
                      NumberFormat.currency(locale: 'id', symbol: "Rp ")
                          .format(jumlah),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.blue),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellStyle: const pw.TextStyle(fontSize: 10),
                ),

                pw.SizedBox(height: 20),
                pw.Text(
                    "Total Pemasukan: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ').format(totalPemasukan)}"),
                pw.Text(
                    "Total Pengeluaran: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ').format(totalPengeluaran)}"),
                pw.Text(
                    "Saldo Akhir: ${NumberFormat.currency(locale: 'id', symbol: 'Rp ').format(saldo)}"),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showSnack("Gagal export PDF: $e");
    }
  }

  // ======================================
  // EXPORT EXCEL
  // ======================================
  Future<void> _exportExcel() async {
    try {
      final transaksi = KeuanganService.getAllTransaksi();
      if (transaksi.isEmpty) {
        _showSnack("Tidak ada data untuk diexport");
        return;
      }

      final workbook = xls.Workbook();
      final sheet = workbook.worksheets[0];

      sheet.getRangeByName('A1').setText("Tanggal");
      sheet.getRangeByName('B1').setText("Jenis");
      sheet.getRangeByName('C1').setText("Nama PT");
      sheet.getRangeByName('D1').setText("Deskripsi");
      sheet.getRangeByName('E1').setText("No.PO");
      sheet.getRangeByName('F1').setText("Jumlah");

      for (var i = 0; i < transaksi.length; i++) {
        final t = transaksi[i];
        final tanggal = t['tanggal'] is DateTime
            ? t['tanggal']
            : DateTime.tryParse(t['tanggal'].toString()) ?? DateTime.now();
        final jumlah = (t['jumlah'] as num).toDouble();

        sheet.getRangeByIndex(i + 2, 1)
            .setText(DateFormat("dd/MM/yyyy").format(tanggal));
        sheet.getRangeByIndex(i + 2, 2).setText(t['jenis'] ?? '');
        sheet.getRangeByIndex(i + 2, 3).setText(t['namaPT'] ?? '');
        sheet.getRangeByIndex(i + 2, 4).setText(t['deskripsi'] ?? '');
        sheet.getRangeByIndex(i + 2, 5).setText(t['noPO'] ?? '');
        sheet.getRangeByIndex(i + 2, 6).setNumber(jumlah);
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/laporan_keuangan.xlsx");
      await file.writeAsBytes(bytes, flush: true);

      Share.shareXFiles([XFile(file.path)], text: "Laporan Keuangan");
    } catch (e) {
      _showSnack("Gagal export Excel: $e");
    }
  }

  // ======================================
  // EXPORT CSV
  // ======================================
  Future<void> _exportCSV() async {
    try {
      final transaksi = KeuanganService.getAllTransaksi();
      if (transaksi.isEmpty) {
        _showSnack("Tidak ada data untuk diexport");
        return;
      }

      List<List<dynamic>> rows = [
        ["Tanggal", "Jenis", "Nama PT", "Deskripsi", "No.PO", "Jumlah"]
      ];

      for (var t in transaksi) {
        final tanggal = t['tanggal'] is DateTime
            ? t['tanggal']
            : DateTime.tryParse(t['tanggal'].toString()) ?? DateTime.now();
        final jumlah = (t['jumlah'] as num).toDouble();

        rows.add([
          DateFormat("dd/MM/yyyy").format(tanggal),
          t['jenis'] ?? '',
          t['namaPT'] ?? '',
          t['deskripsi'] ?? '',
          t['noPO'] ?? '',
          jumlah,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/laporan_keuangan.csv");
      await file.writeAsString(csv);

      Share.shareXFiles([XFile(file.path)], text: "Laporan Keuangan");
    } catch (e) {
      _showSnack("Gagal export CSV: $e");
    }
  }

  // ======================================
  // BUILD UI
  // ======================================
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentPage: '/keuangan',
      title: "Dashboard Keuangan",
      collapsible: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (_isSyncing) const LinearProgressIndicator(minHeight: 4),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: KeuanganService.listenable(),
                    builder: (context, box, _) {
                      var transaksi = KeuanganService.getAllTransaksi();

                      // ===== APPLY FILTER =====
                      if (filterJenis != null) {
                        transaksi = transaksi
                            .where((t) => t['jenis'] == filterJenis)
                            .toList();
                      }
                      if (filterStart != null) {
                        transaksi = transaksi.where((t) {
                          final tanggal = t['tanggal'] is DateTime
                              ? t['tanggal']
                              : DateTime.tryParse(
                                      t['tanggal'].toString()) ??
                                  DateTime.now();
                          return tanggal
                              .isAfter(filterStart!.subtract(const Duration(days: 1)));
                        }).toList();
                      }
                      if (filterEnd != null) {
                        transaksi = transaksi.where((t) {
                          final tanggal = t['tanggal'] is DateTime
                              ? t['tanggal']
                              : DateTime.tryParse(
                                      t['tanggal'].toString()) ??
                                  DateTime.now();
                          return tanggal
                              .isBefore(filterEnd!.add(const Duration(days: 1)));
                        }).toList();
                      }

                      if (transaksi.isEmpty) {
                        return const Center(child: Text("Belum ada data"));
                      }

                      final totalPemasukan = transaksi
                          .where((t) => t['jenis'] == "Pemasukan")
                          .fold<double>(
                              0.0,
                              (sum, t) =>
                                  sum + (t['jumlah'] as num).toDouble());
                      final totalPengeluaran = transaksi
                          .where((t) => t['jenis'] == "Pengeluaran")
                          .fold<double>(
                              0.0,
                              (sum, t) =>
                                  sum + (t['jumlah'] as num).toDouble());
                      final saldo = totalPemasukan - totalPengeluaran;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmall = constraints.maxWidth < 500;

                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // === FILTER BAR ===
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    DropdownButton<String?>(
                                      hint: const Text("Filter Jenis"),
                                      value: filterJenis,
                                      items: const [
                                        DropdownMenuItem(
                                            value: null, child: Text("Semua")),
                                        DropdownMenuItem(
                                            value: "Pemasukan",
                                            child: Text("Pemasukan")),
                                        DropdownMenuItem(
                                            value: "Pengeluaran",
                                            child: Text("Pengeluaran")),
                                      ],
                                      onChanged: (val) =>
                                          setState(() => filterJenis = val),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.date_range),
                                      label: Text(filterStart == null
                                          ? "Mulai"
                                          : DateFormat("dd/MM/yyyy")
                                              .format(filterStart!)),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              filterStart ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => filterStart = picked);
                                        }
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.date_range),
                                      label: Text(filterEnd == null
                                          ? "Selesai"
                                          : DateFormat("dd/MM/yyyy")
                                              .format(filterEnd!)),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              filterEnd ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => filterEnd = picked);
                                        }
                                      },
                                    ),
                                    if (filterJenis != null ||
                                        filterStart != null ||
                                        filterEnd != null)
                                      IconButton(
                                        icon: const Icon(Icons.clear),
                                        tooltip: "Reset Filter",
                                        onPressed: () => setState(() {
                                          filterJenis = null;
                                          filterStart = null;
                                          filterEnd = null;
                                        }),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // EXPORT BUTTONS
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      IconButton(
                                          icon: const Icon(
                                              Icons.picture_as_pdf),
                                          onPressed: _exportPDF,
                                          tooltip: "Export PDF"),
                                      IconButton(
                                          icon:
                                              const Icon(Icons.table_chart),
                                          onPressed: _exportExcel,
                                          tooltip: "Export Excel"),
                                      IconButton(
                                          icon: const Icon(Icons.file_present),
                                          onPressed: _exportCSV,
                                          tooltip: "Export CSV"),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // SUMMARY CARDS
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildSummaryCard(
                                          "Total Pemasukan",
                                          NumberFormat.currency(
                                                  locale: 'id', symbol: "Rp ")
                                              .format(totalPemasukan),
                                          Colors.green),
                                      _buildSummaryCard(
                                          "Total Pengeluaran",
                                          NumberFormat.currency(
                                                  locale: 'id', symbol: "Rp ")
                                              .format(totalPengeluaran),
                                          Colors.red),
                                      _buildSummaryCard(
                                          "Saldo",
                                          NumberFormat.currency(
                                                  locale: 'id', symbol: "Rp ")
                                              .format(saldo),
                                          Colors.blue),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // LIST / TABLE
                                Expanded(
                                  child: isSmall
                                      ? _buildListView(transaksi)
                                      : _buildDataTable(context, transaksi),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================
  // SUMMARY CARD
  // ======================================
  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      margin: const EdgeInsets.only(right: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ======================================
  // LIST VIEW
  // ======================================
  Widget _buildListView(List<Map<String, dynamic>> transaksi) {
    return ListView.builder(
      itemCount: transaksi.length,
      itemBuilder: (context, index) {
        final t = transaksi[index];
        final isPemasukan = t['jenis'] == "Pemasukan";
        final jumlah = (t['jumlah'] as num).toDouble();
        final tanggal = t['tanggal'] is DateTime
            ? t['tanggal']
            : DateTime.tryParse(t['tanggal'].toString()) ?? DateTime.now();
        final bool unsynced = t['unsynced'] == true;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: Icon(
              unsynced ? Icons.cloud_off : Icons.cloud_done,
              color: unsynced ? Colors.red : Colors.green,
            ),
            title: Text("${t['namaPT']} - ${t['jenis']}"),
            subtitle: Text(
                "${DateFormat("dd/MM/yyyy").format(tanggal)}\n${t['deskripsi'] ?? ''}"),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(locale: 'id', symbol: "Rp ")
                      .format(jumlah),
                  style: TextStyle(
                      color: isPemasukan ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long),
                  tooltip: "Lihat Invoice",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => InvoicePage(transaksi: t)),
                    );
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================================
  // DATA TABLE
  // ======================================
  Widget _buildDataTable(BuildContext context, List<Map<String, dynamic>> transaksi) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Ambil total lebar layar
      final double totalWidth = constraints.maxWidth;

      // Tentukan lebar relatif untuk setiap kolom
      final double tanggalWidth = totalWidth * 0.12;
      final double jenisWidth = totalWidth * 0.1;
      final double namaPTWidth = totalWidth * 0.15;
      final double deskripsiWidth = totalWidth * 0.2;
      final double noPOWidth = totalWidth * 0.13;
      final double jumlahWidth = totalWidth * 0.15;
      final double invoiceWidth = totalWidth * 0.15;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width, maxWidth: 1200,),
          
          child: DataTable(
            columnSpacing: 12,
            columns: const [
              DataColumn(label: Text("Tanggal")),
              DataColumn(label: Text("Jenis")),
              DataColumn(label: Text("Nama PT")),
              DataColumn(label: Text("Deskripsi")),
              DataColumn(label: Text("No.PO")),
              DataColumn(label: Text("Jumlah")),
              DataColumn(label: Text("Invoice")),
            ],
            rows: transaksi.map((t) {
              final isPemasukan = t['jenis'] == "Pemasukan";
              final jumlah = (t['jumlah'] as num).toDouble();
              final tanggal = t['tanggal'] is DateTime
                  ? t['tanggal']
                  : DateTime.tryParse(t['tanggal'].toString()) ?? DateTime.now();
              final bool unsynced = t['unsynced'] == true;

              return DataRow(
                cells: [
                  DataCell(SizedBox(
                    width: tanggalWidth,
                    child: Row(
                      children: [
                        Icon(
                          unsynced ? Icons.cloud_off : Icons.cloud_done,
                          size: 14,
                          color: unsynced ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(DateFormat("dd/MM/yyyy").format(tanggal)),
                        ),
                      ],
                    ),
                  )),
                  DataCell(SizedBox(width: jenisWidth, child: Text(t['jenis'] ?? ''))),
                  DataCell(SizedBox(width: namaPTWidth, child: Text(t['namaPT'] ?? ''))),
                  DataCell(SizedBox(width: deskripsiWidth, child: Text(t['deskripsi'] ?? ''))),
                  DataCell(SizedBox(width: noPOWidth, child: Text(t['noPO'] ?? ''))),
                  DataCell(SizedBox(
                    width: jumlahWidth,
                    child: Text(
                      NumberFormat.currency(locale: 'id', symbol: "Rp ").format(jumlah),
                      style: TextStyle(
                        color: isPemasukan ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
                  DataCell(SizedBox(
                    width: invoiceWidth,
                    child: IconButton(
                      icon: const Icon(Icons.receipt_long),
                      tooltip: "Lihat Invoice",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => InvoicePage(transaksi: t)),
                        );
                      },
                    ),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}


  // ======================================
  // ADD DIALOG
  // ======================================
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Tambah Transaksi"),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedJenis,
                    decoration: const InputDecoration(labelText: "Jenis"),
                    items: const [
                      DropdownMenuItem(
                          value: "Pemasukan", child: Text("Pemasukan")),
                      DropdownMenuItem(
                          value: "Pengeluaran", child: Text("Pengeluaran")),
                    ],
                    onChanged: (val) {
                      setState(() => selectedJenis = val!);
                    },
                  ),
                  TextFormField(
                    controller: namaPTController,
                    decoration: const InputDecoration(labelText: "Nama PT"),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Wajib diisi" : null,
                  ),
                  TextFormField(
                    controller: deskripsiController,
                    decoration: const InputDecoration(labelText: "Deskripsi"),
                  ),
                  TextFormField(
                    controller: noPOController,
                    decoration: const InputDecoration(labelText: "No. PO"),
                  ),
                  TextFormField(
                    controller: hargaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Jumlah"),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Wajib diisi" : null,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(DateFormat("dd/MM/yyyy").format(selectedDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;

                final jumlah = double.tryParse(hargaController.text) ?? 0;

                await KeuanganService.addTransaksi(
                  jenis: selectedJenis,
                  namaPT: namaPTController.text,
                  deskripsi: deskripsiController.text,
                  noPO: noPOController.text,
                  jumlah: jumlah,
                  tanggal: selectedDate,
                );

                namaPTController.clear();
                deskripsiController.clear();
                noPOController.clear();
                hargaController.clear();

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
