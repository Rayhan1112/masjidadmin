import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllAdminsScreen extends StatefulWidget {
  const AllAdminsScreen({super.key});

  @override
  State<AllAdminsScreen> createState() => _AllAdminsScreenState();
}

class _AllAdminsScreenState extends State<AllAdminsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double padding = width < 600 ? 16 : 24;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(width),
                const SizedBox(height: 20),
                Expanded(child: _buildAdminsList(width)),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildSearchBar(double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: screenWidth < 400 ? "Search..." : "Search by name or email...",
          prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAdminsList(double screenWidth) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'];
          // Show masjid admins and super admins
          return type == 'masjidAdmin' || type == 'superAdmin' || type == null;
        }).toList();

        // Client-side filtering
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['displayName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search_outlined, size: 60, color: Colors.grey[200]),
                const SizedBox(height: 10),
                Text(
                  _searchQuery.isEmpty ? "No Admins found" : "No results found",
                  style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        if (screenWidth > 900) {
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3.0,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildAdminCard(data, screenWidth, doc.id);
            },
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildAdminCard(data, screenWidth, doc.id);
          },
        );
      },
    );
  }

  Future<void> _deleteAdmin(String uid, Map<String, dynamic> data) async {
    final String? masjidId = data['masjidId'];
    String? masjidName;

    if (masjidId != null) {
      final masjidDoc = await FirebaseFirestore.instance.collection('masjids').doc(masjidId).get();
      if (masjidDoc.exists) {
        masjidName = masjidDoc.data()?['name'];
      }
    }

    final String? choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(masjidId != null ? Icons.warning_amber_rounded : Icons.delete_forever, 
                 color: masjidId != null ? Colors.orange : Colors.red),
            const SizedBox(width: 10),
            Text(masjidId != null ? "Linked Account" : "Delete Admin?"),
          ],
        ),
        content: Text(masjidId != null 
          ? "This admin is linked to: ${masjidName ?? masjidId}.\n\nWhat would you like to delete?"
          : "Are you sure you want to remove this administrator?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, 'user'), 
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(masjidId != null ? "DELETE USER ONLY" : "DELETE ADMIN"),
          ),
          if (masjidId != null)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'both'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("DELETE MASJID & USER"),
            ),
        ],
      ),
    );

    if (choice == 'user' || choice == 'both') {
      try {
        if (choice == 'both' && masjidId != null) {
          await FirebaseFirestore.instance.collection('masjids').doc(masjidId).delete();
        }
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(choice == 'both' ? "Masjid and Admin deleted" : "Admin deleted successfully"), 
              backgroundColor: Colors.green
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> data, String uid) {
    final nameController = TextEditingController(text: data['displayName']);
    final phoneController = TextEditingController(text: data['phone']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Admin Details", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: _inputDecoration("Name", Icons.person_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: _inputDecoration("Phone", Icons.phone_android_rounded),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'displayName': nameController.text.trim(),
                'phone': phoneController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("UPDATE"),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4A90E2), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> data, double screenWidth, String uid) {
    final bool isCompact = screenWidth < 400;
    final String name = data['displayName'] ?? 'Unknown';
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: isCompact ? 20 : 25,
              backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: const Color(0xFF4A90E2),
                  fontWeight: FontWeight.bold,
                  fontSize: isCompact ? 16 : 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 14 : 17,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (data['email'] != null)
                    Row(
                      children: [
                        Icon(Icons.email_outlined,
                            size: isCompact ? 12 : 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['email'],
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: isCompact ? 11 : 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (data['phone'] != null &&
                      data['phone'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: isCompact ? 12 : 14,
                              color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            data['phone'],
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: isCompact ? 11 : 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _showEditDialog(data, uid),
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  tooltip: "Edit Info",
                ),
                IconButton(
                  onPressed: () => _deleteAdmin(uid, data),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: "Delete Admin",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
