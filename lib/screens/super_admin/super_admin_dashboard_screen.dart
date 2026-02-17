import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const SuperAdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _totalAdmins = 0;
  int _totalMasjids = 0;
  int _totalNotifications = 0;
  bool _isLoading = true;
  String _adminName = "Super Admin";

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _loadAdminName();
  }

  void _loadAdminName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _adminName = user.displayName ?? "Super Admin";
      });
    }
  }

  Future<void> _fetchStats() async {
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('users').count().get(),
        db.collection('masjids').count().get(),
        db
            .collection('notification_requests')
            .where('status', isEqualTo: 'sent')
            .count()
            .get(),
      ]);

      if (mounted) {
        setState(() {
          _totalAdmins = results[0].count ?? 0;
          _totalMasjids = results[1].count ?? 0;
          _totalNotifications = results[2].count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsGrid(),
                        const SizedBox(height: 30),
                        _buildSectionHeader("Registration Highlights", onTap: () => widget.onNavigate?.call(1)),
                        const SizedBox(height: 15),
                        _buildRecentMasjidsList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showAdsSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Active Ads"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('ads').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No ads found"));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'text';
                  final isActive = data['isActive'] ?? false;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: type == 'image' 
                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(data['imageUrl'], fit: BoxFit.cover))
                        : const Icon(Icons.text_fields, size: 20),
                    ),
                    title: Text(type == 'image' ? "Image Ad" : (data['content'] ?? "Text Ad"), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Switch(
                      value: isActive,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        FirebaseFirestore.instance.collection('ads').doc(doc.id).update({'isActive': val});
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        double spacing = 12;
        final double cardWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                "Admins",
                _totalAdmins.toString(),
                Icons.admin_panel_settings_rounded,
                const [Color(0xFF6366F1), Color(0xFF818CF8)],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                "Masjids",
                _totalMasjids.toString(),
                Icons.mosque_rounded,
                const [Color(0xFF10B981), Color(0xFF34D399)],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                "Notifs",
                _totalNotifications.toString(),
                Icons.notifications_active_rounded,
                const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                "Ads",
                "Active",
                Icons.campaign_rounded,
                const [Color(0xFFEF4444), Color(0xFFF87171)],
                onTap: _showAdsSelectionDialog,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, List<Color> gradient, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(icon, color: Colors.white.withOpacity(0.15), size: 50),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text("View All"),
        ),
      ],
    );
  }

  Widget _buildRecentMasjidsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('masjids')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text("No data available"),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final created = (data['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
            final formattedDate = DateFormat('MMM d, yyyy').format(created);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.mosque,
                        color: Color(0xFF4A90E2), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] ?? 'Unknown Masjid',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          data['address'] ?? 'No address set',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Joined",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
