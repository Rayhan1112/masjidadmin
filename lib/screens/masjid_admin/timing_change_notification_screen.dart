import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class TimingChangeNotificationScreen extends StatefulWidget {
  const TimingChangeNotificationScreen({super.key});

  @override
  State<TimingChangeNotificationScreen> createState() =>
      _TimingChangeNotificationScreenState();
}

class _TimingChangeNotificationScreenState
    extends State<TimingChangeNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldTimeController = TextEditingController();
  final _newTimeController = TextEditingController();
  final _customMessageController = TextEditingController();

  String _selectedPrayer = 'Fajr';
  bool _isLoading = false;

  final List<String> _prayers = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
    'Jummah',
  ];

  final CollectionReference _notificationsRef =
      FirebaseFirestore.instance.collection('notification_requests');

  Future<void> _sendTimingNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.red,
          content: Text('FATAL ERROR: No authenticated user found!')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final String title = 'Namaz Timing Changed';
      final String body =
          '$_selectedPrayer timing has been changed from ${_oldTimeController.text} to ${_customMessageController.text.isNotEmpty ? _customMessageController.text : _newTimeController.text}';

      final payload = {
        'title': title,
        'body': body,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': user.uid,
        'target': 'timing_change',
        'masjidId': user.uid,
        'type': 'timing_change',
        'changedPrayers': [_selectedPrayer],
        'oldTime': _oldTimeController.text,
        'newTime': _customMessageController.text.isNotEmpty
            ? _customMessageController.text
            : _newTimeController.text,
      };

      await _notificationsRef.add(payload);

      print('📤 Timing change notification created: $payload');

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Timing change notification sent successfully!')));

      // Clear form
      _oldTimeController.clear();
      _newTimeController.clear();
      _customMessageController.clear();
    } catch (e) {
      print('❌ Error creating timing notification: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification deleted.')));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  void dispose() {
    _oldTimeController.dispose();
    _newTimeController.dispose();
    _customMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Column(
        children: [
          _buildHeader(theme, MediaQuery.of(context).padding.top),
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
            child: Icon(Icons.access_time, size: 40, color: Color(0xFF4A90E2)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Timing Change Notification",
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text("Notify users about namaz timing changes",
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
            const Icon(Icons.access_time, color: Color(0xFF4A90E2)),
            const SizedBox(width: 8),
            Flexible(
                child: Text('Send Timing Change',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis))
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedPrayer,
            decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
            items: _prayers
                .map((prayer) => DropdownMenuItem(
                      value: prayer,
                      child: Text(prayer),
                    ))
                .toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() => _selectedPrayer = newValue);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                    controller: _oldTimeController,
                    decoration: InputDecoration(
                        labelText: 'Old Time (e.g., 5:00 AM)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                    validator: (v) => v!.isEmpty ? 'Old time required' : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                    controller: _newTimeController,
                    decoration: InputDecoration(
                        labelText: 'New Time (e.g., 5:30 AM)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                    validator: (v) => v!.isEmpty ? 'New time required' : null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
              controller: _customMessageController,
              decoration: InputDecoration(
                  labelText: 'Custom Message (optional)',
                  hintText: 'Or leave blank to use auto-generated message',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
              maxLines: 2),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendTimingNotification,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: _isLoading
                    ? const Text('Sending...')
                    : const Text('Send Notification')),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history, color: Color(0xFF4A90E2)),
            const SizedBox(width: 8),
            Flexible(
                child: Text('Recent Timing Notifications',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis))
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Query without where clause to avoid composite index requirement
              stream: _notificationsRef
                  .orderBy('sentAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        const Text('Please check Firestore indexes'),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No timing change notifications yet.'));
                }

                // Filter locally for timing_change type
                final allDocs = snapshot.data!.docs;
                final timingDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['type'] == 'timing_change';
                }).toList();

                if (timingDocs.isEmpty) {
                  return const Center(
                      child: Text('No timing change notifications yet.'));
                }

                return ListView.separated(
                  itemCount: timingDocs.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final doc = timingDocs[index];
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
                                child: Text(
                                    notification['title'] ?? 'Timing Changed',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            Text(timeago.format(sentAt),
                                style: theme.textTheme.bodySmall),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteNotification(docId)),
                          ],
                        ),
                        Text(notification['body'] ?? '',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                              'Status: ${notification['status'] ?? 'pending'}',
                              style: theme.textTheme.bodySmall),
                        ),
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
