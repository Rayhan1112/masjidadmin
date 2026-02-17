import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:timeago/timeago.dart' as timeago;
import 'package:masjidadmin/services/notification_api_service.dart';
import 'package:masjidadmin/constants.dart';
import 'package:hijri/hijri_calendar.dart';

class InAppMessageScreen extends StatefulWidget {
  const InAppMessageScreen({super.key});

  @override
  State<InAppMessageScreen> createState() => _InAppMessageScreenState();
}

class _InAppMessageScreenState extends State<InAppMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  XFile? _image;
  final ImagePicker _picker = ImagePicker();

  String _selectedTarget = 'masjid_follower';
  bool _isLoading = false;
  bool _isCustomMode = false;
  final _notificationApi = NotificationApiService();

  final CollectionReference _inAppMessagesRef =
      FirebaseFirestore.instance.collection('in_app_messages');
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
      debugPrint('Error fetching masjids: $e');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      String? imageUrl;
      if (_image != null) {
        final String cloudName = "djlhicadd";
        final String uploadPreset = "mahalaxmi";
        final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = uploadPreset;

        if (kIsWeb) {
          final bytes = await _image!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: _image!.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath('file', _image!.path));
        }

        final response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonResponse = jsonDecode(responseData);
          imageUrl = jsonResponse['secure_url'];
        } else {
          throw Exception('Cloudinary upload failed: ${response.statusCode}');
        }
      }

      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('hh:mm a').format(now);

      final Map<String, dynamic> messageData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageUrl': imageUrl,
        'status': _isSuperAdmin ? 'unseen' : 'waiting_approval',
        'date': formattedDate,
        'time': formattedTime,
        'timestamp': FieldValue.serverTimestamp(),
        'target': _selectedTarget,
        'type': 'in_app_message',
      };

      if (_selectedTarget == 'masjid_follower') {
        if (_isSuperAdmin && _selectedMasjidId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select a masjid.'),
            backgroundColor: Colors.orange,
          ));
          setState(() => _isLoading = false);
          return;
        }

        final targetMasjidId = _isSuperAdmin ? _selectedMasjidId : user.uid;
        messageData['masjidId'] = targetMasjidId;
        messageData['topic'] = 'masjid_$targetMasjidId';
      }

      if (!_isSuperAdmin) {
        messageData['requestedBy'] = user.uid;
        messageData['requestedAt'] = FieldValue.serverTimestamp();
      }

      // Save to Firestore
      await _inAppMessagesRef.add(messageData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981), 
              content: Text(_isSuperAdmin ? 'Message sent successfully!' : 'Sent to Super Admin for approval.')
            )
        );
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          _image = null;
          _isCustomMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMessage(String docId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this in-app message?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _inAppMessagesRef.doc(docId).delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _useTemplate(String title, String body) {
    _titleController.text = title;
    _descriptionController.text = body;
    setState(() {
      _isCustomMode = true;
      _image = null; // Clear previous image when starting from template
    });
  }

  void _useAchiBaatTemplate() {
    final now = DateTime.now();
    final hijri = HijriCalendar.now();
    final formattedDate = DateFormat('d MMMM y').format(now);
    final hijriDate = "${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH";

    _titleController.text = "Aaj ki Achi Baat";
    _descriptionController.text = "📅 Date: $formattedDate\n🌙 Hijri: $hijriDate\n\n✨ ";

    setState(() {
      _isCustomMode = true;
      _image = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmall ? 16 : 24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isCustomMode) ...[
                        _buildBackButton(),
                        const SizedBox(height: 20),
                        _buildComposerCard(isSmall),
                      ] else
                        _buildTemplateSelection(isSmall),
                      const SizedBox(height: 40),
                      _buildHistorySection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildBackButton() {
    return InkWell(
      onTap: () => setState(() => _isCustomMode = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF6366F1)),
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
        _buildSectionTitle("Daily Inspiration"),
        const SizedBox(height: 16),
        // Row 1
        Row(
          children: [
            Expanded(child: _buildTemplateCard("Achi Baat", "Wisdom & Hijri Date", Icons.lightbulb_outline_rounded, const Color(0xFF10B981),
                () => _useAchiBaatTemplate())),
            const SizedBox(width: 16),
            Expanded(child: _buildTemplateCard("Daily Hadith", "Share wisdom", Icons.menu_book_rounded, const Color(0xFFF59E0B), 
                () => _useTemplate("Daily Hadith", "The Prophet (ﷺ) said: 'The best among you are those who have the best manners and character.'"))),
          ],
        ),
        // Row 2
        Row(
          children: [
            Expanded(child: _buildTemplateCard("Jummah", "Friday greetings", Icons.mosque_rounded, const Color(0xFF6366F1),
                () => _useTemplate("Jummah Mubarak", "Jummah Mubarak! Don't forget to read Surah Al-Kahf and send Durood."))),
            const SizedBox(width: 16),
            Expanded(child: _buildTemplateCard("Alert", "Announcements", Icons.campaign_rounded, const Color(0xFFEF4444), 
                () => _useTemplate("Important Announcement", "Please take note of this important update from the Masjid administration."))),
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
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1),
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
              decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
              child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Write Custom Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                  Text("Create a unique announcement with an optional image", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF6366F1)),
          ],
        ),
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
                              leading: const Icon(Icons.mosque_rounded, color: Color(0xFF6366F1), size: 20),
                              title: Text(option['name']),
                              onTap: () => onSelected(option),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              hoverColor: const Color(0xFF6366F1).withOpacity(0.1),
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
              "MESSAGE DETAILS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration("Message Title", Icons.title_rounded),
              validator: (v) => v!.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration("Message Body", Icons.message_rounded),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Body is required' : null,
            ),
            const SizedBox(height: 32),
            const Text(
              "IMAGE (OPTIONAL)",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            _buildImagePickerZone(isSmall),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPreview,
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('PREVIEW'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildPublishButton(),
                ),
              ],
            ),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    );
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.visibility_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('Message Preview', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: kIsWeb
                          ? Image.network(_image!.path, fit: BoxFit.cover)
                          : Image.file(File(_image!.path), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _titleController.text.isEmpty ? 'No Title' : _titleController.text,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  _descriptionController.text.isEmpty ? 'No Description' : _descriptionController.text,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _sendMessage,
        icon: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded, size: 20),
        label: Text(_isLoading ? 'SENDING...' : 'PUBLISH MESSAGE', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "RECENT MESSAGES",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        _buildRecentHistory(false),
      ],
    );
  }

  Widget _buildImagePickerZone(bool isSmall) {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
        ),
        child: _image != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: kIsWeb 
                        ? Image.network(_image!.path, fit: BoxFit.cover, width: double.infinity)
                        : Image.file(File(_image!.path), fit: BoxFit.cover, width: double.infinity),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _image = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.red, size: 20),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: Colors.grey.shade400, size: 40),
                  const SizedBox(height: 10),
                  Text("Attach an Image (Optional)", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendMessage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('POST TO BILLBOARD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      children: [
        _buildSectionTitle("Active Billboard Posts"),
        const Spacer(),
        const Icon(Icons.history_rounded, size: 16, color: Color(0xFF94A3B8)),
      ],
    );
  }

  Widget _buildRecentHistory(bool isSmall) {
    return StreamBuilder<QuerySnapshot>(
      stream: _inAppMessagesRef.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final docs = _isSuperAdmin 
            ? snapshot.data!.docs 
            : snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['masjidId'] == FirebaseAuth.instance.currentUser?.uid;
              }).toList();

        if (docs.isEmpty) return const Center(child: Text("No billboard posts found.", style: TextStyle(color: Color(0xFF94A3B8))));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                      child: Image.network(data['imageUrl'], height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(data['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)))),
                            Text(timeago.format(date), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(data['description'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                              child: Text(data['target'] == 'all_users' ? "Public" : "Masjid Followers", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            ),
                            const Spacer(),
                            IconButton(onPressed: () => _deleteMessage(doc.id), icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20)),
                          ],
                        ),
                      ],
                    ),
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
