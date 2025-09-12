import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfHelper {
  /// 🔹 Widget header (logo kiri + info perusahaan rata tengah + garis bawah)
  static Future<pw.Widget> buildHeader() async {
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
    );

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 🔹 Logo kiri
            pw.Image(logo, width: 70, height: 70),
            pw.SizedBox(width: 10),

            // 🔹 Expanded supaya teks auto-wrap
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    "PT. INTI MAS MULIA",
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "GENERAL CONTRACTOR, SUPPLIER, FABRICATION MECHANICAL & ELECTRICAL",
                    style: pw.TextStyle(font: baseFont, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "Ruko Griya Laguna Mas Blok A No. 09 Tembesi Batam",
                    style: pw.TextStyle(font: baseFont, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "Email: intimasmulia.pt@gmail.com",
                    style: pw.TextStyle(font: baseFont, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "Phone: 0778-3852598 / 0813-7109-0680",
                    style: pw.TextStyle(font: baseFont, fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1),
      ],
    );
  }

  /// 🔹 Template isi dokumen manual
  static Future<pw.Widget> buildBody(
    Map<String, dynamic> doc, {
    pw.ImageProvider? signature,
  }) async {
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 16),
          // Judul isi dokumen
          pw.Center(
            child: pw.Text(
              (doc["judul"] ?? "Dokumen").toString(),
              style: pw.TextStyle(font: boldFont, fontSize: 20),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 16),

          // 🔹 Isi dokumen: bisa String atau List
          if (doc["content"] is List) ...[
            for (var p in doc["content"])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  p.toString(),
                  style: pw.TextStyle(font: baseFont, fontSize: 12),
                  textAlign: pw.TextAlign.justify,
                ),
              ),
          ] else ...[
            pw.Text(
              (doc["content"] ?? "").toString(),
              style: pw.TextStyle(font: baseFont, fontSize: 12),
              textAlign: pw.TextAlign.justify,
            ),
          ],

          pw.Spacer(),
          pw.SizedBox(height: 30),

          // 🔹 Tanda tangan
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              children: [
                pw.Text("Hormat Kami,", style: pw.TextStyle(font: baseFont)),
                pw.SizedBox(height: 50),
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
                      (doc["penandatangan"] ?? "Direktur").toString(),
                      style: pw.TextStyle(font: boldFont),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Preview dokumen manual
  static Future<void> previewManual(
    Map<String, dynamic> doc, {
    File? signatureFile,
  }) async {
    try {
      final pdf = pw.Document();
      pw.ImageProvider? signature;

      if (signatureFile != null) {
        final bytes = await signatureFile.readAsBytes();
        signature = pw.MemoryImage(bytes);
      }

      final header = await buildHeader();
      final body = await buildBody(doc, signature: signature);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [header, body],
          ),
        ),
      );

      final bytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      print("❌ Error previewManual: $e");
    }
  }

  /// 🔹 Simpan dokumen manual ke PDF
  static Future<void> saveManual(
    Map<String, dynamic> doc, {
    File? signatureFile,
  }) async {
    try {
      final pdf = pw.Document();
      pw.ImageProvider? signature;

      if (signatureFile != null) {
        final bytes = await signatureFile.readAsBytes();
        signature = pw.MemoryImage(bytes);
      }

      final header = await buildHeader();
      final body = await buildBody(doc, signature: signature);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [header, body],
          ),
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: "${doc["judul"] ?? "dokumen"}.pdf",
      );
    } catch (e) {
      print("❌ Error saveManual: $e");
    }
  }

  /// 🔹 Preview dokumen hasil upload
  static Future<void> previewFile(Map<String, dynamic> doc) async {
    try {
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = doc["bytes"] as Uint8List?;
      } else {
        if (doc["path"] != null) {
          final file = File(doc["path"]);
          bytes = await file.readAsBytes();
        }
      }

      await Printing.layoutPdf(onLayout: (_) async => bytes ?? Uint8List(0));
    } catch (e) {
      print("❌ Error previewFile: $e");
    }
  }

  /// 🔹 Simpan dokumen hasil upload
  static Future<void> savePdf(Map<String, dynamic> doc) async {
    try {
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = doc["bytes"] as Uint8List?;
      } else {
        if (doc["path"] != null) {
          final file = File(doc["path"]);
          bytes = await file.readAsBytes();
        }
      }

      await Printing.sharePdf(
        bytes: bytes ?? Uint8List(0),
        filename: doc["judul"] ?? "dokumen.pdf",
      );
    } catch (e) {
      print("❌ Error savePdf: $e");
    }
  }

  // ==========================================================
  // 🔹 Tambahan: Generate & Preview PDF Tabel
  // ==========================================================

  /// Generate PDF tabel dari List<List<String>>
  static Future<Uint8List> generateTablePdf(
    List<List<String>> data, {
    List<String>? headers,
    String? title,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 18,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 12,
                ),
                cellStyle: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 11,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(width: 0.5),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Preview tabel PDF
  static Future<void> previewTablePdf(
    List<List<String>> data, {
    List<String>? headers,
    String? title,
  }) async {
    try {
      final bytes = await generateTablePdf(
        data,
        headers: headers,
        title: title,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      print("❌ Error previewTablePdf: $e");
    }
  }

  /// Simpan & share tabel PDF
  static Future<void> saveTablePdf(
    List<List<String>> data, {
    List<String>? headers,
    String? title,
    String? filename,
  }) async {
    try {
      final bytes = await generateTablePdf(
        data,
        headers: headers,
        title: title,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename ?? "${title ?? "tabel"}.pdf",
      );
    } catch (e) {
      print("❌ Error saveTablePdf: $e");
    }
  }
}
