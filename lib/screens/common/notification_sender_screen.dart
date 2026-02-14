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

  String _selectedTarget = 'masjid_followers';
  bool _isLoading = false;

  final _apiService = NotificationApiService();
  final CollectionReference _notificationsRef =
      FirebaseFirestore.instance.collection('notification_requests');
  final CollectionReference _masjidsRef =
      FirebaseFirestore.instance.collection('masjids');

  bool _isSuperAdmin = false;
  String? _selectedMasjidId;
  List<Map<String, dynamic>> _masjids = [];

  @override
  void initState() {
    super.initState();
    _checkSuperAdminStatus();
  }

  void _checkSuperAdminStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == kSuperAdminEmail) {
      setState(() {
        _isSuperAdmin = true;
      });
      _fetchMasjids();
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
      print('Error fetching masjids: $e');
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
      // If super admin and masjid_followers target, ensure a masjid is selected
      if (_isSuperAdmin &&
          _selectedTarget == 'masjid_followers' &&
          _selectedMasjidId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Please select a masjid first.')));
        setState(() => _isLoading = false);
        return;
      }

      final masjidId = (_isSuperAdmin && _selectedTarget == 'masjid_followers')
          ? _selectedMasjidId
          : user.uid;

      // Create notification request in Firestore
      // The backend listener will pick this up and send the FCM notification
      await _notificationsRef.add({
        'title': _titleController.text,
        'body': _bodyController.text,
        'target': _selectedTarget,
        'masjidId': masjidId,
        'sentBy': user.uid,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Pending status triggers the backend listener
        'data': {
          'sentBy': user.uid,
          'masjidId': masjidId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification scheduled successfully!')));
      _titleController.clear();
      _bodyController.clear();
    } catch (e) {
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
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool _isCustomMode = false;

  void _useTemplate(String title, String body) {
    _titleController.text = title;
    _bodyController.text = body;
    setState(() => _isCustomMode = true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isSmall = width < 600;
        final double padding = isSmall ? 16 : 24;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              _buildHeader(isSmall),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isCustomMode) _buildTemplateSelection(isSmall),
                          if (_isCustomMode) ...[
                            _buildBackButton(),
                            const SizedBox(height: 20),
                            _buildSendSection(isSmall),
                          ],
                          const SizedBox(height: 40),
                          _buildHistoryHeader(),
                          const SizedBox(height: 16),
                          _buildRecentHistory(isSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: Color(0xFF6366F1), size: 24),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Communications",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                "Broadcast updates to your community",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => setState(() => _isCustomMode = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: Color(0xFF6366F1)),
          const SizedBox(width: 8),
          const Text(
            "BACK TO TEMPLATES",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6366F1),
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Quick Templates"),
        const SizedBox(height: 16),
        if (isSmall)
          Column(
            children: [
              _buildTemplateCard("Jamat Update", "Prayer time changes", Icons.schedule_rounded, const Color(0xFF6366F1), 
                () => _useTemplate("Prayer Time Update", "The Jamat time for [Prayer] has changed to [Time].")),
              _buildTemplateCard("Announcement", "General news & alerts", Icons.campaign_rounded, const Color(0xFFF59E0B),
                () => _useTemplate("Masjid Announcement", "Important Update: ")),
              _buildTemplateCard("Ijtema", "Invite for gatherings", Icons.groups_rounded, const Color(0xFF10B981),
                () => _useTemplate("Weekly Gathering", "Join us for our weekly ijtema after...")),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildTemplateCard("Jamat Update", "Prayer time changes", Icons.schedule_rounded, const Color(0xFF6366F1), 
                () => _useTemplate("Prayer Time Update", "The Jamat time for [Prayer] has changed to [Time]."))),
              const SizedBox(width: 16),
              Expanded(child: _buildTemplateCard("Announcement", "General news & alerts", Icons.campaign_rounded, const Color(0xFFF59E0B),
                () => _useTemplate("Masjid Announcement", "Important Update: "))),
              const SizedBox(width: 16),
              Expanded(child: _buildTemplateCard("Ijtema", "Invite for gatherings", Icons.groups_rounded, const Color(0xFF10B981),
                () => _useTemplate("Weekly Gathering", "Join us for our weekly ijtema after..."))),
            ],
          ),
        const SizedBox(height: 24),
        _buildCustomDraftCard(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTemplateCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDraftCard() {
    return InkWell(
      onTap: () => setState(() => _isCustomMode = true),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_document, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Create Custom Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                  Text("Write your own title and content from scratch", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSendSection(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Recipient Group"),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTarget,
              decoration: _inputDecoration("Target Audience", Icons.people_rounded),
              items: const [
                DropdownMenuItem(value: 'all_users', child: Text('All System Users')),
                DropdownMenuItem(value: 'masjid_followers', child: Text('Specific Masjid Followers')),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) setState(() => _selectedTarget = newValue);
              },
            ),
            if (_isSuperAdmin && _selectedTarget == 'masjid_followers') ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedMasjidId,
                isExpanded: true,
                hint: const Text('Select target Masjid'),
                decoration: _inputDecoration("Select Masjid", Icons.mosque_rounded),
                items: _masjids.map((masjid) {
                  return DropdownMenuItem<String>(
                    value: masjid['id'],
                    child: Text(masjid['name']),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedMasjidId = newValue);
                },
                validator: (v) => v == null ? 'Please select a masjid' : null,
              ),
            ],
            const SizedBox(height: 32),
            _buildSectionTitle("Message Content"),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration("Notice Title", Icons.title_rounded),
              validator: (v) => v!.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _bodyController,
              decoration: _inputDecoration("Full Description", Icons.subject_rounded),
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Body is required' : null,
            ),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
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
            : const Text('PUBLISH NOTIFICATION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      children: [
        _buildSectionTitle("Transmission Logs"),
        const Spacer(),
        const Icon(Icons.history_toggle_off_rounded, size: 16, color: Color(0xFF94A3B8)),
      ],
    );
  }

  Widget _buildRecentHistory(bool isSmall) {
    return StreamBuilder<QuerySnapshot>(
      stream: _isSuperAdmin
          ? _notificationsRef.orderBy('sentAt', descending: true).snapshots()
          : _notificationsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = _isSuperAdmin 
            ? snapshot.data!.docs 
            : snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['sentBy'] == FirebaseAuth.instance.currentUser?.uid;
              }).toList();

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade200),
                const SizedBox(height: 10),
                const Text("No notification logs found.", style: TextStyle(color: Color(0xFF94A3B8))),
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
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['sentAt'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['title'] ?? 'Untitied',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              timeago.format(date),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['body'] ?? '',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => _deleteNotification(doc.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
