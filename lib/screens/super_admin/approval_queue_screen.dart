import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class ApprovalQueueScreen extends StatefulWidget {
  const ApprovalQueueScreen({super.key});

  @override
  State<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends State<ApprovalQueueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleApproval(String docId, String collection, Map<String, dynamic> data, bool isApproved) async {
    setState(() => _isProcessing = true);
    try {
      final db = FirebaseFirestore.instance;
      if (isApproved) {
        if (collection == 'notification_requests') {
          // For notifications, set status to 'pending'
          // The Node.js server listener will pick it up and send the push
          await db.collection(collection).doc(docId).update({
            'status': 'pending',
            'approvedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // For in-app messages, set status to 'unseen' to make it live
          await db.collection(collection).doc(docId).update({
            'status': 'unseen',
            'approvedAt': FieldValue.serverTimestamp(),
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Request approved and published!'),
          ));
        }
      } else {
        // Reject - Mark as rejected
        await db.collection(collection).doc(docId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Request rejected.'),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF6366F1),
          tabs: const [
            Tab(text: 'Notifications', icon: Icon(Icons.notifications_active_rounded, size: 20)),
            Tab(text: 'Billboard Posts', icon: Icon(Icons.art_track_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('notification_requests'),
          _buildRequestList('in_app_messages'),
        ],
      ),
    );
  }

  Widget _buildRequestList(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('status', isEqualTo: 'waiting_approval')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        
        // Sort in memory to avoid needing a composite index in Firestore
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final timeA = ((a.data() as Map<String, dynamic>)['requestedAt'] ?? (a.data() as Map<String, dynamic>)['timestamp']) as Timestamp?;
          final timeB = ((b.data() as Map<String, dynamic>)['requestedAt'] ?? (b.data() as Map<String, dynamic>)['timestamp']) as Timestamp?;
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA); // Descending
        });

        if (sortedDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.checklist_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('No pending requests found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildRequestCard(doc.id, collection, data);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(String docId, String collection, Map<String, dynamic> data) {
    final timestamp = (data['requestedAt'] ?? data['timestamp']) as Timestamp?;
    final timeStr = timestamp != null ? timeago.format(timestamp.toDate()) : 'Recently';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['imageUrl'] != null)
              Image.network(data['imageUrl'], height: 150, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['target'] == 'all_users' ? 'ALL USERS' : 'MASJID FOLLOWERS',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                        ),
                      ),
                      const Spacer(),
                      Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
                  const SizedBox(height: 6),
                  Text(data['description'] ?? data['body'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessing ? null : () => _handleApproval(docId, collection, data, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : () => _handleApproval(docId, collection, data, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
