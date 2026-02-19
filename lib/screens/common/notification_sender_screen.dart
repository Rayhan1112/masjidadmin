import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:masjidadmin/services/notification_api_service.dart';
import 'package:masjidadmin/constants.dart';

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

  String _selectedTarget = 'masjid_follower';
  bool _isLoading = false;

  final _apiService = NotificationApiService();
  final CollectionReference _notificationsRef =
      FirebaseFirestore.instance.collection('notification_requests');
  final CollectionReference _masjidsRef =
      FirebaseFirestore.instance.collection('masjids');

  bool _isSuperAdmin = false;
  String? _masjidId;
  String? _selectedMasjidId;
  List<Map<String, dynamic>> _masjids = [];

  @override
  void initState() {
    super.initState();
    _checkStatusAndFetchData();
  }

  Future<void> _checkStatusAndFetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.email == kSuperAdminEmail) {
      setState(() {
        _isSuperAdmin = true;
      });
      _fetchMasjids();
    } else {
      // Fetch masjidId for Masjid Admin
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _masjidId = doc.data()?['masjidId'] ?? user.uid;
        });
      }
    }
  }

  Future<void> _fetchMasjids() async {
    try {
      final snapshot = await _masjidsRef.get();
      final masjids = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Masjid',
        };
      }).toList();
      setState(() {
        _masjids = masjids;
      });
    } catch (e) {
      debugPrint('Error fetching masjids: $e');
    }
  }

  Future<void> _sendNotification() async {
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
      if (_isSuperAdmin &&
          _selectedTarget == 'masjid_follower' &&
          _selectedMasjidId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Please select a masjid first.')));
        setState(() => _isLoading = false);
        return;
      }

      final masjidId = _isSuperAdmin
          ? (_selectedTarget == 'masjid_follower' ? _selectedMasjidId : 'all')
          : _masjidId;

      // Logic: If Super Admin, send directly. If Masjid Admin, send for approval.
      if (_isSuperAdmin) {
        // 1. Log to Firestore for history
        await _notificationsRef.add({
          'title': _titleController.text,
          'body': _bodyController.text,
          'target': _selectedTarget,
          'masjidId': masjidId,
          'sentBy': user.uid,
          'sentAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'sent',
        });

        // 2. Immediate Delivery via API
        await _apiService.sendNotification(
          title: _titleController.text,
          body: _bodyController.text,
          target: _selectedTarget,
          masjidId: masjidId,
        );
      } else {
        // Masjid Admin Flow: Send for Approval
        await _notificationsRef.add({
          'title': _titleController.text,
          'body': _bodyController.text,
          'target': _selectedTarget,
          'masjidId': masjidId,
          'requestedBy': user.uid,
          'masjidName': 'Masjid Admin', 
          'requestedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'waiting_approval',
          'type': 'notification',
        });

        // 3. Alert Super Admin
        await _apiService.sendToTopic(
          topic: 'super_admin_alerts',
          title: 'New Notification Approval Requested',
          body: 'A masjid admin has requested a notification to be broadcast: "${_titleController.text}"',
          data: {'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'screen': 'approvals'},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(_isSuperAdmin 
                ? 'Notification broadcasted successfully!' 
                : 'Sent to Super Admin for approval.')));
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text('Broadcast Error: $e')));
      }
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
        title: const Text('Remove from Logs?'),
        content: const Text('This will delete the history record. The notification has already been sent.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _notificationsRef.doc(docId).delete();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildComposerCard(isSmall),
                    const SizedBox(height: 40),
                    _buildHistorySection(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernHeader(bool isSmall) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.podcasts_rounded, color: Color(0xFF4F46E5), size: 28),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Broadcast Center",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                "Send push notifications to your audience",
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCard(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AUDIENCE",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTarget,
              decoration: _inputDecoration("Target Group", Icons.people_alt_rounded),
              items: const [
                DropdownMenuItem(value: 'masjid_follower', child: Text('Masjid Followers')),
                DropdownMenuItem(value: 'all_users', child: Text('All App Users')),
              ],
              onChanged: (v) => setState(() => _selectedTarget = v!),
            ),
            if (_isSuperAdmin && _selectedTarget == 'masjid_follower') ...[
              const SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _masjids;
                  }
                  return _masjids.where((masjid) {
                    return masjid['name']
                        .toString()
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                displayStringForOption: (Map<String, dynamic> option) => option['name'],
                onSelected: (Map<String, dynamic> selection) {
                  setState(() {
                    _selectedMasjidId = selection['id'];
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  // Pre-fill with selected masjid name
                  if (_selectedMasjidId != null && controller.text.isEmpty) {
                    final selectedMasjid = _masjids.firstWhere(
                      (m) => m['id'] == _selectedMasjidId,
                      orElse: () => {'name': ''},
                    );
                    controller.text = selectedMasjid['name'] ?? '';
                  }
                  
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: _inputDecoration("Search & Select Masjid", Icons.mosque_rounded),
                    validator: (v) => _selectedMasjidId == null ? 'Please select a masjid' : null,
                    onEditingComplete: onEditingComplete,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        width: 300,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(Icons.mosque_rounded, color: Color(0xFF4F46E5), size: 20),
                              title: Text(option['name']),
                              onTap: () => onSelected(option),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              hoverColor: const Color(0xFF4F46E5).withOpacity(0.1),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 32),
            const Text(
              "QUICK TEMPLATES",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTemplateChip('🕌 Prayer Time', 'Prayer Time Update', 'Namaz timings have been updated.'),
                _buildTemplateChip('📢 Announcement', 'Important Announcement', 'Please check this important update.'),
                _buildTemplateChip('🎉 Event', 'Upcoming Event', 'Join us for an upcoming community event.'),
                _buildTemplateChip('📚 Ramadan', 'Ramadan Mubarak', 'Ramadan Kareem to all our community members!'),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "MESSAGE DETAILS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration("Notification Title", Icons.title_rounded),
              validator: (v) => v!.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: _inputDecoration("Message Body", Icons.message_rounded),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Body is required' : null,
            ),
            const SizedBox(height: 40),
            _buildPublishButton(),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
    );
  }

  Widget _buildTemplateChip(String label, String title, String body) {
    return InkWell(
      onTap: () {
        setState(() {
          _titleController.text = title;
          _bodyController.text = body;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4F46E5),
          ),
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendNotification,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('SEND NOW', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ],
              ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              "RECENT TRANSMISSIONS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
            ),
            Spacer(),
            Icon(Icons.history_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _isSuperAdmin 
              ? _notificationsRef.orderBy('createdAt', descending: true).limit(20).snapshots()
              : (_masjidId != null 
                  ? _notificationsRef.where('masjidId', isEqualTo: _masjidId).orderBy('createdAt', descending: true).limit(20).snapshots()
                  : _notificationsRef.orderBy('createdAt', descending: true).limit(20).snapshots()),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint("Firestore Query Error: ${snapshot.error}");
              // Fallback to simple query if composite index is missing
              return StreamBuilder<QuerySnapshot>(
                stream: _notificationsRef.orderBy('createdAt', descending: true).limit(20).snapshots(),
                builder: (context, fallbackSnapshot) {
                  if (!fallbackSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final allDocs = fallbackSnapshot.data!.docs;
                  final filteredDocs = _isSuperAdmin 
                      ? allDocs 
                      : allDocs.where((d) => (d.data() as Map)['masjidId'] == _masjidId).toList();
                  return _buildHistoryList(filteredDocs);
                },
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            return _buildHistoryList(snapshot.data!.docs);
          },
        ),
      ],
    );
  }

  Widget _buildHistoryList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: const Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text("No transmission history", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final status = data['status'] ?? 'sent';
        final isPending = status == 'waiting_approval';
        final time = (data['createdAt'] ?? data['sentAt'] ?? data['requestedAt']) as Timestamp?;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isPending ? Colors.orange.shade100 : Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: (isPending ? Colors.orange : const Color(0xFF10B981)).withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(
                    isPending ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                    color: isPending ? Colors.orange : const Color(0xFF10B981),
                    size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(data['title'] ?? 'No Title',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        if (isPending)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                            child: const Text("PENDING",
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ),
                      ],
                    ),
                    Text(data['body'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time != null)
                    Text(timeago.format(time.toDate()),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () => _deleteNotification(docs[index].id),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
