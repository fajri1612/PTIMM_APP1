import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class InvoicePage extends StatefulWidget {
  final Map<String, dynamic>? transaksi;

  const InvoicePage({super.key, this.transaksi});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  Uint8List? signatureBytes;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

  // Format rupiah
  String formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  // Format tanggal
  String formatTanggal(dynamic tanggal) {
    try {
      DateTime parsed;
      if (tanggal == null) {
        parsed = DateTime.now();
      } else if (tanggal is DateTime) {
        parsed = tanggal;
      } else {
        parsed = DateTime.tryParse(tanggal.toString()) ?? DateTime.now();
      }
      return DateFormat('dd/MM/yyyy', 'id_ID').format(parsed);
    } catch (_) {
      return DateFormat('dd/MM/yyyy', 'id_ID').format(DateTime.now());
    }
  }

  String generateInvoiceNumber() {
    final now = DateTime.now();
    return "INV-${DateFormat('yyyyMMddHHmmss').format(now)}";
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isNotEmpty) {
      final data = await _signatureController.toPngBytes();
      if (data != null) {
        setState(() {
          signatureBytes = data;
        });
      }
    }
  }

  void _clearSignature() {
    _signatureController.clear();
    setState(() {
      signatureBytes = null;
    });
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();

    final jumlah = widget.transaksi?['jumlah'] ?? 0;
    final jumlahFormatted = formatRupiah(jumlah);
    final tanggal = formatTanggal(widget.transaksi?['tanggal']);
    final namaPT = widget.transaksi?['namaPT'] ?? '-';
    final deskripsi = widget.transaksi?['deskripsi'] ?? '-';
    final nomorInvoice = generateInvoiceNumber();

    final logoBytes = await rootBundle.load('assets/images/logo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pw.ImageProvider? signature;
    if (signatureBytes != null) {
      signature = pw.MemoryImage(signatureBytes!);
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🔹 HEADER PERUSAHAAN
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(logo, width: 80, height: 80),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "PT. INTI MAS MULIA",
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "GENERAL CONTRACTOR, SUPPLIER, FABRICATION MECHANICAL & ELECTRICAL",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        "Ruko Griya Laguna Mas Blok A No 09 Tembesi Batam",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        "Phone : 0778 3852598 / 0813 7109 0680",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        "Email : intimasmulia.pt@gmail.com",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // 🔹 JUDUL INVOICE
              pw.Center(
                child: pw.Text(
                  "INVOICE",
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // 🔹 DETAIL INVOICE
              pw.Text("Nomor Invoice: $nomorInvoice"),
              pw.Text("Tanggal: $tanggal"),
              pw.Text("Nama PT: $namaPT"),
              pw.SizedBox(height: 20),
              pw.Text("Deskripsi: $deskripsi"),
              pw.Text("Jumlah: $jumlahFormatted"),
              pw.Divider(),
              pw.Text(
                "Total: $jumlahFormatted",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),

              pw.Spacer(),

              // 🔹 BAGIAN TANDA TANGAN
              pw.SizedBox(height: 40),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  children: [
                    pw.Text("Hormat Kami,"),
                    pw.SizedBox(height: 60), // ruang untuk tanda tangan manual
                    if (signature != null)
                      pw.Image(signature, width: 120, height: 60),
                    pw.Container(
                      width: 120,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(width: 1),
                        ),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          "",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _previewPdf() async {
    await Printing.layoutPdf(onLayout: (format) async => await _buildPdf());
  }

  Future<void> _downloadPdf() async {
    final bytes = await _buildPdf();

    // 🔹 Nama file = Nama PT + Nomor Invoice
    final namaPT = (widget.transaksi?['namaPT'] ?? 'Invoice')
        .toString()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_'); // aman utk nama file
    final nomorInvoice = generateInvoiceNumber();
    final filename = "${namaPT}_$nomorInvoice.pdf";

    if (kIsWeb) {
      // Web → langsung download/share PDF
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
      return;
    }

    if (Platform.isAndroid) {
      // Android → cek & request izin storage
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }

      final dir = await getTemporaryDirectory();
      final tempPath = "${dir.path}/$filename";
      final file = File(tempPath);
      await file.writeAsBytes(bytes);

      final mediaStore = MediaStore();
      await mediaStore.saveFile(
        tempFilePath: tempPath,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: "Invoices",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ PDF berhasil disimpan: $filename")),
        );
      }
      return;
    }

    // iOS / Desktop
    final dir = await getTemporaryDirectory();
    final tempPath = "${dir.path}/$filename";
    final file = File(tempPath);
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ PDF berhasil disimpan di: $tempPath")),
      );
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jumlah = widget.transaksi?['jumlah'] ?? 0;
    final jumlahFormatted = formatRupiah(jumlah);
    final tanggal = formatTanggal(widget.transaksi?['tanggal']);
    final namaPT = widget.transaksi?['namaPT'] ?? '-';
    final deskripsi = widget.transaksi?['deskripsi'] ?? '-';
    final nomorInvoice = generateInvoiceNumber();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _previewPdf,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadPdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Preview Invoice",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text("Nomor Invoice: $nomorInvoice"),
              Text("Tanggal: $tanggal"),
              Text("Nama PT: $namaPT"),
              const SizedBox(height: 20),
              Text("Deskripsi: $deskripsi"),
              Text("Jumlah: $jumlahFormatted"),
              const Divider(),
              Text(
                "Total: $jumlahFormatted",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 30),
              const Text(
                "Tanda Tangan Direktur:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                height: 150,
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _saveSignature,
                    child: const Text("Simpan TTD"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _clearSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text("Hapus"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (signatureBytes != null) ...[
                const Text("Preview Tanda Tangan:"),
                const SizedBox(height: 10),
                Image.memory(signatureBytes!, width: 120, height: 60),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
