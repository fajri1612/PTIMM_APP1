import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PT IMM App',
      home: Scaffold(
        appBar: AppBar(title: const Text("Firebase Test")),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              try {
                final userCredential = await FirebaseAuth.instance
                    .createUserWithEmailAndPassword(
                  email: "test@gmail.com",
                  password: "123456",
                );
                print("User created: ${userCredential.user!.uid}");
              } catch (e) {
                print("Error: $e");
              }
            },
            child: const Text("Register Test"),
          ),
        ),
      ),
    );
  }
}
