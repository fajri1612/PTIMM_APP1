import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'main_layout.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _loading = true;

  Uint8List? _profileImage;
  String? _photoURL;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _divisionController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Load data dari SharedPreferences + Firestore
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _nameController.text = prefs.getString("name") ?? "";
      _emailController.text = prefs.getString("email") ?? user?.email ?? "";
      _phoneController.text = prefs.getString("phone") ?? "";
      _divisionController.text = prefs.getString("division") ?? "";
      _addressController.text = prefs.getString("address") ?? "";
      _photoURL = prefs.getString("photoURL");
    });

    if (user != null) {
      final doc =
          await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data["name"] ?? _nameController.text;
          _emailController.text = data["email"] ?? _emailController.text;
          _phoneController.text = data["phone"] ?? _phoneController.text;
          _divisionController.text = data["division"] ?? _divisionController.text;
          _addressController.text = data["address"] ?? _addressController.text;
          _photoURL = data["photoURL"];
        });

        await _saveToCache();
      }
    }

    setState(() => _loading = false);
  }

  /// Pilih gambar dari gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImage = bytes;
      });
    }
  }

  /// Upload gambar ke Firebase Storage
  Future<String?> _uploadImage(Uint8List fileBytes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final ref =
        FirebaseStorage.instance.ref().child("profile_pictures/${user.uid}.jpg");

    await ref.putData(fileBytes, SettableMetadata(contentType: "image/jpeg"));
    return await ref.getDownloadURL();
  }

  /// Simpan ke local cache
  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("name", _nameController.text);
    await prefs.setString("email", _emailController.text);
    await prefs.setString("phone", _phoneController.text);
    await prefs.setString("division", _divisionController.text);
    await prefs.setString("address", _addressController.text);

    if (_photoURL != null) {
      await prefs.setString("photoURL", _photoURL!);
    }
  }

  /// Simpan ke Firestore + Storage
  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_profileImage != null) {
      _photoURL = await _uploadImage(_profileImage!);
    }

    await _saveToCache();

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "name": _nameController.text,
      "email": _emailController.text,
      "phone": _phoneController.text,
      "division": _divisionController.text,
      "address": _addressController.text,
      "photoURL": _photoURL,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _isEditing = false;
    });
  }

  /// Tampilkan dialog konfirmasi logout
  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Logout"),
        content: const Text("Yakin mau logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentPage: '/profile',
      title: "Profil",
      collapsible: true,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    /// FOTO PROFIL
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileImage != null
                              ? MemoryImage(_profileImage!)
                              : (_photoURL != null
                                  ? NetworkImage(_photoURL!)
                                  : const AssetImage("assets/images/profile.jpg"))
                          as ImageProvider,
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 4,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blue,
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    /// FORM
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            enabled: _isEditing,
                            decoration: const InputDecoration(labelText: "Nama"),
                          ),
                          TextFormField(
                            controller: _emailController,
                            enabled: false,
                            decoration: const InputDecoration(labelText: "Email"),
                          ),
                          TextFormField(
                            controller: _phoneController,
                            enabled: _isEditing,
                            decoration:
                                const InputDecoration(labelText: "Nomor HP"),
                          ),
                          TextFormField(
                            controller: _divisionController,
                            enabled: _isEditing,
                            decoration:
                                const InputDecoration(labelText: "Divisi"),
                          ),
                          TextFormField(
                            controller: _addressController,
                            enabled: _isEditing,
                            decoration:
                                const InputDecoration(labelText: "Alamat"),
                          ),
                          const SizedBox(height: 20),

                          /// TOMBOL EDIT / SIMPAN
                          _isEditing
                              ? Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _saveProfile,
                                      icon: const Icon(Icons.save),
                                      label: const Text("Simpan"),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() => _isEditing = false);
                                      },
                                      icon: const Icon(Icons.cancel),
                                      label: const Text("Batal"),
                                    ),
                                  ],
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() => _isEditing = true);
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text("Edit Profil"),
                                ),

                          const SizedBox(height: 20),

                          /// TOMBOL LOGOUT
                          ElevatedButton.icon(
                            onPressed: _confirmLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text("Logout"),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
