import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:masjidadmin/screens/super_admin/all_masjids_screen.dart';
import 'package:masjidadmin/screens/super_admin/user_list_screen.dart';
import 'package:masjidadmin/screens/super_admin/masjid_stats_screen.dart';
import 'package:masjidadmin/services/notification_api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalMasjids = 0;
  int _usersWithMasjid = 0;
  
  String _mostSelectedMasjidName = "Loading...";
  String? _mostSelectedMasjidId;
  int _mostSelectedMasjidCount = 0;
  
  String _mostNotificationsMasjidName = "Loading...";
  String? _mostNotificationsMasjidId;
  int _mostNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      // 1. Basic Counts - Inclusive of all regular users
      // Fetch all to ensure we catch users with missing 'type' fields
      final allUsersSnapshot = await db.collection('users').get();
      
      final regularUsers = allUsersSnapshot.docs.where((doc) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toLowerCase();
        // Exclude known admin types
        return type != 'superadmin' && type != 'super_admin' && type != 'masjidadmin';
      }).toList();

      final totalUsers = regularUsers.length;

      final masjidCountSnapshot = await db.collection('masjids')
          .count()
          .get();
      final totalMasjids = masjidCountSnapshot.count ?? 0;
      
      // 2. Users with selected masjid (Followers) - ONLY standard users
      final followers = regularUsers.where((doc) {
        final data = doc.data();
        final subscribed = data['subscribedMasajid'];
        if (subscribed is List) return subscribed.isNotEmpty;
        if (subscribed is String) return subscribed.isNotEmpty;
        
        final masjidId = data['masjidId'] as String?;
        return masjidId != null && masjidId.isNotEmpty;
      }).toList();
      final usersWithMasjidCount = followers.length;
      
      // 3. Most Selected Masjid Aggregation
      Map<String, int> masjidSelectionFrequencies = {};
      for (var doc in followers) {
        final data = doc.data();
        final subscribed = data['subscribedMasajid'];
        
        if (subscribed is List) {
          for (var mid in subscribed) {
            if (mid is String && mid.isNotEmpty) {
              masjidSelectionFrequencies[mid] = (masjidSelectionFrequencies[mid] ?? 0) + 1;
            }
          }
        } else if (subscribed is String && subscribed.isNotEmpty) {
          masjidSelectionFrequencies[subscribed] = (masjidSelectionFrequencies[subscribed] ?? 0) + 1;
        } else {
          final masjidId = data['masjidId'] as String?;
          if (masjidId != null && masjidId.isNotEmpty) {
            masjidSelectionFrequencies[masjidId] = (masjidSelectionFrequencies[masjidId] ?? 0) + 1;
          }
        }
      }

      String mostSelectedId = "";
      int maxSelection = 0;
      masjidSelectionFrequencies.forEach((id, count) {
        if (count > maxSelection) {
          maxSelection = count;
          mostSelectedId = id;
        }
      });

      String mostSelectedName = "None";
      if (mostSelectedId.isNotEmpty) {
        final masjidDoc = await db.collection('masjids').doc(mostSelectedId).get();
        mostSelectedName = masjidDoc.data()?['name'] ?? mostSelectedId;
      }

      // 4. Most Notifications Aggregation (Most Active Masjid)
      final notificationsQuery = await db.collection('notification_requests')
          .where('status', isEqualTo: 'sent')
          .get();
      
      Map<String, int> notificationFrequencies = {};
      for (var doc in notificationsQuery.docs) {
        final masjidId = doc.data()['masjidId'] as String?;
        if (masjidId != null && masjidId.isNotEmpty) {
          notificationFrequencies[masjidId] = (notificationFrequencies[masjidId] ?? 0) + 1;
        }
      }

      String mostNotifId = "";
      int maxNotif = 0;
      notificationFrequencies.forEach((id, count) {
        if (count > maxNotif) {
          maxNotif = count;
          mostNotifId = id;
        }
      });

      String mostNotifName = "None";
      if (mostNotifId.isNotEmpty) {
        final masjidDoc = await db.collection('masjids').doc(mostNotifId).get();
        mostNotifName = masjidDoc.data()?['name'] ?? mostNotifId;
      }

      if (mounted) {
        setState(() {
          _totalUsers = totalUsers;
          _totalMasjids = totalMasjids;
          _usersWithMasjid = usersWithMasjidCount;
          _mostSelectedMasjidName = mostSelectedName;
          _mostSelectedMasjidId = mostSelectedId;
          _mostSelectedMasjidCount = maxSelection;
          _mostNotificationsMasjidName = mostNotifName;
          _mostNotificationsMasjidId = mostNotifId;
          _mostNotificationsCount = maxNotif;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickStats(),
                    const SizedBox(height: 30),
                    _buildInsightCard(
                      title: "Most Selected Masjid",
                      value: _mostSelectedMasjidName,
                      subtitle: "$_mostSelectedMasjidCount users following",
                      icon: Icons.favorite_rounded,
                      color: Colors.pinkAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MasjidStatsScreen(
                              title: "Most Selected Masjids",
                              isNotificationMode: false,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInsightCard(
                      title: "Most Active Masjid",
                      value: _mostNotificationsMasjidName,
                      subtitle: "$_mostNotificationsCount notifications sent",
                      icon: Icons.campaign_rounded,
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MasjidStatsScreen(
                              title: "Most Active Masjids",
                              isNotificationMode: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    _buildActivityChart(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickStats() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatBox("Total Users", _totalUsers.toString(), Icons.people_rounded, [const Color(0xFF6366F1), const Color(0xFF818CF8)], onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserListScreen(showAppBar: true, title: "All Users")),
          );
        }),
        _buildStatBox("Total Masjids", _totalMasjids.toString(), Icons.mosque_rounded, [const Color(0xFF10B981), const Color(0xFF34D399)], onTap: () {
          // Navigating to AllMasjidsScreen. Since it's a standalone screen, we just push it.
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AllMasjidsScreen(showAppBar: true)),
          );
        }),
        _buildStatBox("Masjid Followers", _usersWithMasjid.toString(), Icons.star_rounded, [const Color(0xFFF59E0B), const Color(0xFFFBBF24)], onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserListScreen(onlyFollowers: true, showAppBar: true, title: "Masjid Followers")),
          );
        }),
      ],
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, List<Color> colors, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 600 ? 180 : double.infinity),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(title, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard({required String title, required String value, required String subtitle, required IconData icon, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Engagement Rate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 20),
          _buildProgressBar("Users following a Masjid", _totalUsers > 0 ? _usersWithMasjid / _totalUsers : 0, Colors.blue),
          const SizedBox(height: 16),
          _buildProgressBar("Masjids with active admins", 0.75, Colors.green), // Mocking for now
          const SizedBox(height: 16),
          _buildProgressBar("Notification reach", 0.90, Colors.orange), // Mocking for now
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            Text("${(value * 100).toInt()}%", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
