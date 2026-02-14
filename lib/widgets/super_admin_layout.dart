import 'package:flutter/material.dart';
import 'super_admin_sidebar.dart';

class SuperAdminLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  final String title;

  const SuperAdminLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false, // Align left for a modern dashboard look
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
              child: const Icon(Icons.person, size: 18, color: Color(0xFF4A90E2)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      ),
      drawer: Drawer(
        elevation: 0,
        child: SuperAdminSidebar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
             onDestinationSelected(index);
             Navigator.pop(context); // Close drawer on selection
          },
        ),
      ),
      body: child,
    );
  }
}
