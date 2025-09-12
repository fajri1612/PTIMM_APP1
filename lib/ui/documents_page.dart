import 'dart:io' show File;
//ignore: unused_import
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'main_layout.dart';
import '../src/services/documents_service.dart';
import '../utils/pdf_helper.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _syncing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _syncDocuments();
  }

  Future<void> _syncDocuments() async {
    setState(() => _syncing = true);
    await DocumentService.syncOfflineData();
    setState(() => _syncing = false);
  }

  Future<void> _scrollToTop() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  /// Upload file (gambar / dokumen)
  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png'
      ],
      withData: true, // 🔹 penting di Web agar dapat bytes
    );

    if (result == null) return;

    final file = result.files.single;

    if (kIsWeb) {
      // Web tidak ada path, gunakan bytes
      await DocumentService.addDocument(
        judul: file.name,
        kategori: "File Upload",
        bytes: file.bytes,
        manual: false,
      );
    } else {
      // Mobile/Desktop: gunakan path file
      await DocumentService.addDocument(
        judul: file.name,
        kategori: "File Upload",
        path: file.path!,
        manual: false,
      );
    }

    await _syncDocuments();
    _scrollToTop();
  }

  /// Pilih tanda tangan (gambar dari device)
  Future<File?> _pickSignature() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (result == null) return null;
    return File(result.files.single.path!);
  }

  /// Tambah/Edit dokumen manual
  void _editManual({Map<String, dynamic>? doc, int? index}) {
    final judulController = TextEditingController(text: doc?["judul"] ?? "");
    final isiController =
        TextEditingController(text: doc?["content"] ?? ""); // 🔹 content, bukan isi
    final penandatanganController =
        TextEditingController(text: doc?["penandatangan"] ?? "");
    File? signatureFile =
        doc?["signaturePath"] != null ? File(doc!["signaturePath"]) : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(doc == null ? "✍ Tambah Dokumen" : "✏ Edit Dokumen"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: judulController,
                  decoration: const InputDecoration(labelText: "Judul Dokumen"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: isiController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                      labelText: "Isi Dokumen", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: penandatanganController,
                  decoration:
                      const InputDecoration(labelText: "Nama Penandatangan"),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pickedFile = await _pickSignature();
                    if (pickedFile != null) {
                      setDialogState(() => signatureFile = pickedFile);
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Pilih Tanda Tangan"),
                ),
                if (signatureFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Image.file(signatureFile!, height: 60),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final data = {
                  "judul": judulController.text.trim(),
                  "content": isiController.text.trim(), // 🔹 gunakan "content"
                  "penandatangan": penandatanganController.text.trim(),
                  "manual": true,
                  "signaturePath": signatureFile?.path,
                };

                if (index != null) {
                  await DocumentService.updateDocument(index, data);
                } else {
                  await DocumentService.addDocument(
                    judul: data["judul"]?.toString() ?? "Dokumen",
                    kategori: "Dokumen Manual",
                    manual: true,
                    content: data["content"]?.toString() ?? "",
                    penandatangan:
                        data["penandatangan"]?.toString() ?? "Direktur",
                    path: data["signaturePath"] as String?,
                  );
                }

                if (context.mounted) Navigator.pop(context);
                await _syncDocuments();
                _scrollToTop();
              },
              icon: const Icon(Icons.save),
              label: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Dokumen"),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: MainLayout(
        currentPage: '/documents',
        title: "Dashboard Dokumen",
        collapsible: true,
        child: Column(
          children: [
            // 🔹 Tombol di atas list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploadFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[400],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text("Upload File"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editManual(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[400],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text("Tambah Dokumen"),
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Daftar dokumen dengan pull-to-refresh
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: DocumentService.listenable(),
                builder: (context, box, _) {
                  final docs = DocumentService.getAllDocuments();
                  if (docs.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _syncDocuments,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(
                            height: 400,
                            child: Center(
                              child: Text("Belum ada dokumen 📂",
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _syncDocuments,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final manual = doc["manual"] == true;
                        final synced = !(doc["unsynced"] ?? true);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: Icon(
                              manual ? Icons.description : Icons.upload_file,
                              color: manual ? Colors.teal : Colors.brown,
                            ),
                            title: Text(doc["judul"] ?? ""),
                            subtitle: Text(
                              manual
                                  ? "Dokumen Manual"
                                  : "Upload: ${doc["judul"] ?? "-"}",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  synced
                                      ? Icons.cloud_done
                                      : Icons.cloud_off,
                                  color: synced ? Colors.green : Colors.red,
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (val) async {
                                    if (val == "preview") {
                                      if (manual) {
                                        await PdfHelper.previewManual(
                                          doc,
                                          signatureFile: doc["signaturePath"] !=
                                                  null
                                              ? File(doc["signaturePath"])
                                              : null,
                                        );
                                      } else {
                                        await PdfHelper.previewFile(doc);
                                      }
                                    }
                                    if (val == "save") {
                                      if (manual) {
                                        await PdfHelper.saveManual(
                                          doc,
                                          signatureFile: doc["signaturePath"] !=
                                                  null
                                              ? File(doc["signaturePath"])
                                              : null,
                                        );
                                      } else {
                                        await PdfHelper.savePdf(doc);
                                      }
                                    }
                                    if (val == "delete") {
                                      DocumentService.deleteDocument(i);
                                      await _syncDocuments();
                                    }
                                    if (val == "edit" && manual) {
                                      _editManual(doc: doc, index: i);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: "preview",
                                        child: Text("👁 Preview")),
                                    const PopupMenuItem(
                                        value: "save",
                                        child: Text("💾 Simpan PDF")),
                                    if (manual)
                                      const PopupMenuItem(
                                          value: "edit", child: Text("✏ Edit")),
                                    const PopupMenuItem(
                                        value: "delete",
                                        child: Text("🗑 Hapus")),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
