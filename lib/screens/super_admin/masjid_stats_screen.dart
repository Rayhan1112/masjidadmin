import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:masjidadmin/screens/super_admin/user_list_screen.dart';

class MasjidStatsScreen extends StatefulWidget {
  final String title;
  final bool isNotificationMode;

  const MasjidStatsScreen({
    super.key,
    required this.title,
    this.isNotificationMode = true,
  });

  @override
  State<MasjidStatsScreen> createState() => _MasjidStatsScreenState();
}

class _MasjidStatsScreenState extends State<MasjidStatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isLoading = true;
  List<Map<String, dynamic>> _masjidStats = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Fetch all masjids
      final masjidsSnapshot = await db.collection('masjids').get();
      
      // 2. Fetch all standard users (excluding admins) for follower count
      final allUsersSnapshot = await db.collection('users').get();
      final usersDocs = allUsersSnapshot.docs.where((doc) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toLowerCase();
        return type != 'superadmin' && type != 'super_admin' && type != 'masjidadmin';
      });
      
      // 3. Fetch all sent notifications for activity count
      final notificationsSnapshot = await db.collection('notification_requests')
          .where('status', isEqualTo: 'sent')
          .get();

      // Aggregate Followers
      Map<String, int> followerCounts = {};
      for (var doc in usersDocs) {
        final data = doc.data();
        final subscribed = data['subscribedMasajid'];
        
        if (subscribed is List) {
          for (var mid in subscribed) {
            if (mid is String && mid.isNotEmpty) {
              followerCounts[mid] = (followerCounts[mid] ?? 0) + 1;
            }
          }
        } else if (subscribed is String && subscribed.isNotEmpty) {
          followerCounts[subscribed] = (followerCounts[subscribed] ?? 0) + 1;
        } else {
          final mid = data['masjidId'] as String?;
          if (mid != null && mid.isNotEmpty) {
            followerCounts[mid] = (followerCounts[mid] ?? 0) + 1;
          }
        }
      }

      // Aggregate Notifications
      Map<String, int> notificationCounts = {};
      for (var doc in notificationsSnapshot.docs) {
        final mid = doc.data()['masjidId'] as String?;
        if (mid != null && mid.isNotEmpty) {
          notificationCounts[mid] = (notificationCounts[mid] ?? 0) + 1;
        }
      }

      // Combine into a list
      List<Map<String, dynamic>> stats = [];
      for (var doc in masjidsSnapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        stats.add({
          'id': id,
          'name': data['name'] ?? 'Unknown Masjid',
          'address': data['address'] ?? 'No address',
          'followers': followerCounts[id] ?? 0,
          'notifications': notificationCounts[id] ?? 0,
        });
      }

      // Sort based on mode
      if (widget.isNotificationMode) {
        stats.sort((a, b) => b['notifications'].compareTo(a['notifications']));
      } else {
        stats.sort((a, b) => b['followers'].compareTo(a['followers']));
      }

      if (mounted) {
        setState(() {
          _masjidStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching masjid stats: $e");
      if (mounted) setState(() => _isLoading = false);
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
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildMasjidList()),
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
            hintText: "Search masjid by name...",
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

  Widget _buildMasjidList() {
    final filtered = _masjidStats.where((m) => m['name'].toString().toLowerCase().contains(_searchQuery)).toList();

    if (filtered.isEmpty) {
      return Center(child: Text("No masjids found", style: TextStyle(color: Colors.grey[400])));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final masjid = filtered[index];
        final count = widget.isNotificationMode ? masjid['notifications'] : masjid['followers'];
        final label = widget.isNotificationMode ? "Notifications" : "Followers";
        final icon = widget.isNotificationMode ? Icons.campaign_rounded : Icons.people_rounded;
        final color = widget.isNotificationMode ? Colors.orangeAccent : Colors.blueAccent;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserListScreen(
                  filterMasjidId: masjid['id'],
                  title: "Followers of ${masjid['name']}",
                  showAppBar: true,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.mosque_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(masjid['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(masjid['address'], style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
