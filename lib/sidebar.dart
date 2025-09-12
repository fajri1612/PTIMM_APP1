import 'package:flutter/material.dart';

class Sidebar extends StatefulWidget {
  final String currentPage;
  final bool collapsible;

  const Sidebar({
    super.key,
    required this.currentPage,
    this.collapsible = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 70 : 250,
      color: const Color(0xFF0A2F6B),
      child: Column(
        children: [
          // Tombol collapse
          if (widget.collapsible)
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  isCollapsed ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    isCollapsed = !isCollapsed;
                  });
                },
              ),
            ),

          // Bagian Logo + Nama PT
          if (!isCollapsed) ...[
            Container(
              height: 220,
              color: const Color(0xFF0A2F6B),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "PT. INTI MAS MULIA",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Menu navigasi
          _buildMenuItem(
            context,
            icon: Icons.dashboard,
            label: "Dashboard",
            page: '/dashboard',
          ),
          _buildMenuItem(
            context,
            icon: Icons.attach_money,
            label: "Keuangan",
            page: '/keuangan',
          ),
          _buildMenuItem(
            context,
            icon: Icons.folder,
            label: "Dokumen",
            page: '/documents',
          ),
          _buildMenuItem(
            context,
            icon: Icons.person,
            label: "Profile",
            page: '/profile',
          ),
        ],
      ),
    );
  }

  // Fungsi reusable buat menu item
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String page,
  }) {
    final bool isActive = widget.currentPage == page;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? Colors.amber : Colors.white,
      ),
      title: isCollapsed
          ? null
          : Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.amber : Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
      onTap: () {
        if (!isActive) {
          Navigator.pushReplacementNamed(context, page);
        }
      },
    );
  }
}
