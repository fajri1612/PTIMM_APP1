import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InputKeuanganPage extends StatefulWidget {
  const InputKeuanganPage({super.key});

  @override
  State<InputKeuanganPage> createState() => _InputKeuanganPageState();
}

class _InputKeuanganPageState extends State<InputKeuanganPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _namaPTController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _noPOController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();

  String? _jenis;

  final formatter = NumberFormat.decimalPattern('id');

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.openBox("keuanganBox");
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _namaPTController.dispose();
    _deskripsiController.dispose();
    _noPOController.dispose();
    _hargaController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat("yyyy-MM-dd").format(picked);
      });
    }
  }

  Future<void> _simpanData() async {
    if (_formKey.currentState!.validate()) {
      final transaksi = {
        "tanggal": _tanggalController.text,
        "jenis": _jenis,
        "namaPT": _namaPTController.text,
        "deskripsi": _deskripsiController.text,
        "noPO": _noPOController.text,
        "harga": int.parse(_hargaController.text.replaceAll(".", "")),
        "createdAt": FieldValue.serverTimestamp(),
        "unsynced": false, // default, akan diubah kalau gagal simpan online
      };

      final box = Hive.box("keuanganBox");

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .collection("keuangan")
              .add(transaksi);
        }

        // simpan ke Hive (versi sinkron)
        await box.add(transaksi);
      } catch (e) {
        // kalau gagal upload, tandai unsynced
        transaksi["unsynced"] = true;
        await box.add(transaksi);

        debugPrint("Gagal simpan ke Firestore: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Disimpan offline, akan sinkron otomatis nanti.")),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, transaksi);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Input Transaksi")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tanggalController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Tanggal",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _pilihTanggal(context),
                validator: (val) => val!.isEmpty ? "Pilih tanggal" : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _jenis,
                items: const [
                  DropdownMenuItem(value: "Pemasukan", child: Text("Pemasukan")),
                  DropdownMenuItem(value: "Pengeluaran", child: Text("Pengeluaran")),
                ],
                onChanged: (val) => setState(() => _jenis = val),
                decoration: const InputDecoration(labelText: "Jenis"),
                validator: (val) => val == null ? "Pilih jenis" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _namaPTController,
                decoration: const InputDecoration(labelText: "Nama PT"),
                validator: (val) => val!.isEmpty ? "Masukkan nama PT" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deskripsiController,
                decoration: const InputDecoration(labelText: "Deskripsi"),
                validator: (val) => val!.isEmpty ? "Masukkan deskripsi" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noPOController,
                decoration: const InputDecoration(labelText: "No. PO"),
                validator: (val) => val!.isEmpty ? "Masukkan No. PO" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Harga"),
                validator: (val) => val!.isEmpty ? "Masukan Total Harga" : null,
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    final parsed = int.tryParse(val.replaceAll(".", "")) ?? 0;
                    final newText = formatter.format(parsed);
                    _hargaController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _simpanData,
                child: const Text("Simpan"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
