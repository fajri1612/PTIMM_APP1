import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';


import 'ui/login_page.dart';
import 'ui/register_page.dart';
import 'ui/forgot_password_page.dart';
import 'ui/dashboard_page.dart';
import 'ui/keuangan_page.dart';
import 'ui/documents_page.dart';
import 'ui/profile_page.dart';
import 'ui/invoice_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  // ✅ Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Init Hive (lokal storage)
  await Hive.initFlutter();
  await Hive.openBox('documentBox');
  await Hive.openBox('transaksiBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PT IMM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login', // ✅ tetap mulai dari login
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/keuangan': (context) => const KeuanganPage(), // Hive -> transaksiBox
        '/documents': (context) => const DocumentsScreen(),
        '/profile': (context) => const ProfilePage(),
        '/invoice': (context) {
          final transaksi = ModalRoute.of(context)!.settings.arguments;

          if (transaksi is Map) {
            return InvoicePage(
              transaksi: Map<String, dynamic>.from(transaksi),
            );
          }

          return const Scaffold(
            body: Center(
              child: Text("Data transaksi tidak valid"),
            ),
          );
        },
      },
    );
  }
}
