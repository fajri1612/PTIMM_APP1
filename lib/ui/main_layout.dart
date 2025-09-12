import 'package:flutter/material.dart';
import 'package:ptimm_app1/sidebar.dart';

class MainLayout extends StatelessWidget {
  final String currentPage;
  final String title;
  final Widget child;
  final bool collapsible;

  const MainLayout({
    super.key,
    required this.currentPage,
    required this.title,
    required this.child,
    this.collapsible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: collapsible ? Sidebar(currentPage: currentPage) : null,

      appBar: collapsible
          ? AppBar(
              backgroundColor: Colors.grey[200],
              title: Text(
                title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              iconTheme: const IconThemeData(color: Colors.black), // warna ☰
              actions: [
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                )
              ],
            )
          : null,

      body: collapsible
          ? child
          : Row(
              children: [
                Sidebar(currentPage: currentPage),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 60,
                        color: Colors.grey[200],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person),
                              onPressed: () {
                                Navigator.pushNamed(context, '/profile');
                              },
                            )
                          ],
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
