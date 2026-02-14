import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

// Logger utility for console output
void _logNotificationStatus(String action, Map<String, dynamic> data) {
  print('═══════════════════════════════════════════════════════════');
  print('📱 NOTIFICATION $action');
  print('═══════════════════════════════════════════════════════════');
  print('🕐 Timestamp: ${DateTime.now().toIso8601String()}');
  print('👤 User ID: ${data['userId'] ?? 'N/A'}');
  print('🎯 Target: ${data['target'] ?? 'N/A'}');
  print('📌 Masjid ID: ${data['masjidId'] ?? 'N/A'}');
  print('📝 Title: ${data['title'] ?? 'N/A'}');
  print('💬 Body: ${data['body'] ?? 'N/A'}');
  print('📄 Document ID: ${data['docId'] ?? 'N/A'}');
  print('═══════════════════════════════════════════════════════════');
}

void _logNotificationResult(String status, String message) {
  print('📊 NOTIFICATION RESULT: $status - $message');
}

class NotificationSenderScreen extends StatefulWidget {
  const NotificationSenderScreen({super.key});

  @override
  State<NotificationSenderScreen> createState() =>
      _NotificationSenderScreenState();
}

class _NotificationSenderScreenState extends State<NotificationSenderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _selectedTarget = 'masjid_followers';
  bool _isLoading = false;

  final CollectionReference _notificationsRef =
      FirebaseFirestore.instance.collection('notification_requests');

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) {
      _logNotificationResult('FAILED', 'Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logNotificationResult('ERROR', 'No authenticated user found');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.red,
          content: Text('FATAL ERROR: No authenticated user found!')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final Map<String, dynamic> payload = {
        'title': _titleController.text,
        'body': _bodyController.text,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': user.uid,
        'target': _selectedTarget,
      };

      if (_selectedTarget == 'masjid_followers') {
        payload['masjidId'] = user.uid;
      }

      // Log notification details before sending
      _logNotificationStatus('SENDING', {
        'userId': user.uid,
        'target': _selectedTarget,
        'masjidId': _selectedTarget == 'masjid_followers' ? user.uid : null,
        'title': _titleController.text,
        'body': _bodyController.text,
      });

      final docRef = await _notificationsRef.add(payload);
      final docId = docRef.id;

      // Log success
      _logNotificationStatus('SENT SUCCESSFULLY', {
        'userId': user.uid,
        'target': _selectedTarget,
        'masjidId': _selectedTarget == 'masjid_followers' ? user.uid : null,
        'title': _titleController.text,
        'body': _bodyController.text,
        'docId': docId,
      });
      _logNotificationResult('SUCCESS', 'Notification queued successfully');
      _logNotificationResult('DOCUMENT', 'Firestore document created: $docId');

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully!')));
      _titleController.clear();
      _bodyController.clear();
    } catch (e) {
      _logNotificationResult('ERROR', 'Failed to send notification: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Database Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteNotification(String docId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content:
            const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _notificationsRef.doc(docId).delete();
        _logNotificationResult('DELETED', 'Notification deleted: $docId');
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification deleted.')));
      } catch (e) {
        _logNotificationResult('ERROR', 'Failed to delete notification: $e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Column(
        // Removed SafeArea from here
        children: [
          _buildHeader(theme,
              MediaQuery.of(context).padding.top), // Pass status bar height
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _buildSendSection(theme),
                    ),
                  ),
                ],
                body: _buildRecentSection(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, double topPadding) {
    return Container(
      // Adjusted padding: include status bar height + a smaller fixed padding
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF4A90E2),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child:
                Icon(Icons.notifications, size: 40, color: Color(0xFF4A90E2)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Send Notifications",
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text("Manage your alerts",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendSection(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active_outlined,
                color: Color(0xFF4A90E2)),
            const SizedBox(width: 8),
            Flexible(
                child: Text('Send Notification',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis))
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedTarget,
            decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
            items: const [
              DropdownMenuItem(
                  value: 'masjid_follower', child: Text('Masjid Followers')),
              DropdownMenuItem(value: 'all_users', child: Text('All Users')),
            ],
            onChanged: (String? newValue) {
              if (newValue != null) setState(() => _selectedTarget = newValue);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                  labelText: 'Notification Title',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
              validator: (v) => v!.isEmpty ? 'Title is required' : null),
          const SizedBox(height: 12),
          TextFormField(
              controller: _bodyController,
              decoration: InputDecoration(
                  labelText: 'Notification Body',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Body is required' : null),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _isLoading ? null : _sendNotification,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Send')),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 0.0), // Corrected: ensure 'padding:' is named
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history_toggle_off, color: Color(0xFF4A90E2)),
            const SizedBox(width: 8),
            Flexible(
                child: Text('Recent Notifications',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis))
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _notificationsRef
                  .orderBy('sentAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(child: Text('No recent notifications.'));

                final notifications = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final notification = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;
                    final Timestamp? timestamp = notification['sentAt'];
                    final sentAt = timestamp?.toDate() ?? DateTime.now();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(notification['title'] ?? 'No Title',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            Text(timeago.format(sentAt),
                                style: theme.textTheme.bodySmall),
                            IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteNotification(docId)),
                          ],
                        ),
                        Text(notification['body'] ?? 'No Body',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
