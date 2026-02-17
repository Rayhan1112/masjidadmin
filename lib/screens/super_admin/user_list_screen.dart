import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserListScreen extends StatefulWidget {
  final String? filterMasjidId;
  final bool onlyFollowers;
  final String? title;
  final bool showAppBar;

  const UserListScreen({
    super.key,
    this.filterMasjidId,
    this.onlyFollowers = false,
    this.title,
    this.showAppBar = false,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  Map<String, String> _masjidNames = {};

  @override
  void initState() {
    super.initState();
    _fetchMasjidNames();
  }

  Future<void> _fetchMasjidNames() async {
    final snapshot = await FirebaseFirestore.instance.collection('masjids').get();
    final Map<String, String> names = {
      for (var doc in snapshot.docs) 
        doc.id: (doc.data()['name'] ?? 'Unknown').toString()
    };
    if (mounted) {
      setState(() {
        _masjidNames = names;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar 
        ? AppBar(
            title: Text(widget.title ?? "Users List", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E293B),
            elevation: 0,
            centerTitle: true,
          )
        : null,
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: "Search by name, email or phone...",
            prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  })
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    Query query = FirebaseFirestore.instance.collection('users');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;

        // Primary Filter: Only standard users (exclude admins and super admins)
        // This client-side filter is now redundant if server-side 'type' filter is strict,
        // but keeping it for robustness if 'type' field might be missing or not 'user'
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type']?.toString().toLowerCase();
          // Assume null type is also a regular user if that's the default, 
          // but user said "type users", so let's be strict if possible.
          // Usually, for these apps, default is often null or 'user'
          return type == 'user' || type == null || type == "" ;
        }).toList();

        // Apply client-side search query
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['displayName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final phone = (data['phone'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery) || phone.contains(_searchQuery);
          }).toList();
        }

        // Secondary filter for 'onlyFollowers' or specific masjid
        if (widget.filterMasjidId != null) {
           docs = docs.where((doc) {
             final data = doc.data() as Map<String, dynamic>;
             final subscribed = data['subscribedMasajid'];
             final masjidId = data['masjidId'];
             
             if (subscribed is List) return subscribed.contains(widget.filterMasjidId);
             if (subscribed is String) return subscribed == widget.filterMasjidId;
             return masjidId == widget.filterMasjidId;
           }).toList();
        } else if (widget.onlyFollowers) {
           docs = docs.where((doc) {
             final data = doc.data() as Map<String, dynamic>;
             final subscribed = data['subscribedMasajid'];
             final masjidId = data['masjidId'];
             
             if (subscribed is List) return subscribed.isNotEmpty;
             if (subscribed is String) return subscribed.isNotEmpty;
             return masjidId != null && masjidId.toString().isNotEmpty;
           }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Text("No users found", style: TextStyle(color: Colors.grey[400])));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                   Text(
                     "Found ${docs.length} matches",
                     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                   ),
                   const Spacer(),
                   if (widget.filterMasjidId != null) 
                     _buildNotificationCountBadge(widget.filterMasjidId!),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final masjidId = data['masjidId'];
                  final subscribed = data['subscribedMasajid'];
                  
                  String displayMasjidName = "No Masjid Selected";
                  bool hasMasjid = false;

                  if (subscribed is List && subscribed.isNotEmpty) {
                    final names = subscribed.map((id) => _masjidNames[id] ?? id.toString()).toList();
                    displayMasjidName = names.join(', ');
                    hasMasjid = true;
                  } else if (subscribed is String && subscribed.isNotEmpty) {
                    displayMasjidName = _masjidNames[subscribed] ?? subscribed;
                    hasMasjid = true;
                  } else if (masjidId != null && masjidId.isNotEmpty) {
                    displayMasjidName = _masjidNames[masjidId] ?? 'Unknown';
                    hasMasjid = true;
                  }
                  
                  final lastLogin = (data['lastLogin'] as Timestamp?)?.toDate();
      
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blueAccent.withOpacity(0.1),
                          child: const Icon(Icons.person_rounded, color: Colors.blueAccent),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['displayName'] ?? data['phone'] ?? 'Unknown User', 
                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(data['email'] ?? 'No email', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.mosque_rounded, size: 14, color: Color(0xFF4A90E2)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(displayMasjidName, 
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, 
                                                        color: hasMasjid ? const Color(0xFF4A90E2) : Colors.grey)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBadge('USER'),
                            const SizedBox(height: 8),
                            if (lastLogin != null)
                              Text("Active: ${DateFormat('MMM d').format(lastLogin)}", 
                                   style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCountBadge(String masjidId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('notification_requests')
          .where('masjidId', isEqualTo: masjidId)
          .where('status', isEqualTo: 'sent')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final count = snapshot.data!.docs.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.campaign_rounded, size: 14, color: Colors.orangeAccent),
              const SizedBox(width: 6),
              Text("$count notifications sent", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildBadge(String label) {
    Color color = Colors.blue;
    if (label == 'SUPER_ADMIN') color = Colors.red;
    if (label == 'MASJIDADMIN') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
    );
  }
}
