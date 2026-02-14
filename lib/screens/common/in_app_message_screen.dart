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
import 'package:masjidadmin/constants.dart';

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

  String _selectedTarget = 'masjid_topic';
  bool _isLoading = false;
  bool _isCustomMode = false;

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
        'status': 'unseen',
        'date': formattedDate,
        'time': formattedTime,
        'timestamp': FieldValue.serverTimestamp(),
        'target': _selectedTarget,
      };

      if (_selectedTarget == 'masjid_topic') {
        if (_isSuperAdmin && _selectedMasjidId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a masjid.')));
          setState(() => _isLoading = false);
          return;
        }

        final targetMasjidId = _isSuperAdmin ? _selectedMasjidId : user.uid;
        messageData['masjidId'] = targetMasjidId;
        messageData['topic'] = 'masjid_$targetMasjidId';
      }

      await _inAppMessagesRef.add(messageData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Color(0xFF10B981), content: Text('Message sent successfully!')));
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
    setState(() => _isCustomMode = true);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isSmall = width < 600;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              _buildHeader(isSmall),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmall ? 16 : 24),
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
        bottom: 20,
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 24),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "In-App Billboard",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                "Post messages directly to user home feed",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
        if (isSmall)
          Column(
            children: [
              _buildTemplateCard("Daily Hadith", "Share wisdom with users", Icons.menu_book_rounded, const Color(0xFFF59E0B), 
                () => _useTemplate("Daily Hadith", "The Prophet (ﷺ) said: 'The best among you are those who have the best manners and character.'")),
              _buildTemplateCard("Jummah Mubarak", "Weekly Friday greetings", Icons.mosque_rounded, const Color(0xFF6366F1),
                () => _useTemplate("Jummah Mubarak", "Jummah Mubarak! Don't forget to read Surah Al-Kahf and send Durood.")),
              _buildTemplateCard("Special Event", "Invite to masjid gatherings", Icons.event_note_rounded, const Color(0xFF10B981),
                () => _useTemplate("Masjid Event", "Join us for a special lecture this weekend after Isha.")),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildTemplateCard("Daily Hadith", "Share wisdom", Icons.menu_book_rounded, const Color(0xFFF59E0B), 
                () => _useTemplate("Daily Hadith", "The Prophet (ﷺ) said: 'The best among you are those who have the best manners and character.'"))),
              const SizedBox(width: 16),
              Expanded(child: _buildTemplateCard("Jummah Mubarak", "Friday greetings", Icons.mosque_rounded, const Color(0xFF6366F1),
                () => _useTemplate("Jummah Mubarak", "Jummah Mubarak! Don't forget to read Surah Al-Kahf and send Durood."))),
              const SizedBox(width: 16),
              Expanded(child: _buildTemplateCard("Special Event", "Gathetings", Icons.event_note_rounded, const Color(0xFF10B981),
                () => _useTemplate("Masjid Event", "Join us for a special lecture this weekend after Isha."))),
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

  Widget _buildSendSection(bool isSmall) {
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
            _buildSectionTitle("Destination"),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTarget,
              decoration: _inputDecoration("Target Group", Icons.people_rounded),
              items: const [
                DropdownMenuItem(value: 'masjid_topic', child: Text('Masjid Followers')),
                DropdownMenuItem(value: 'all_users', child: Text('All System Users')),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) setState(() => _selectedTarget = newValue);
              },
            ),
            if (_isSuperAdmin && _selectedTarget == 'masjid_topic') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMasjidId,
                isExpanded: true,
                hint: const Text('Select target Masjid'),
                decoration: _inputDecoration("Target Masjid", Icons.mosque_rounded),
                items: _masjids.map((masjid) {
                  return DropdownMenuItem<String>(value: masjid['id'], child: Text(masjid['name']));
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedMasjidId = newValue);
                },
                validator: (v) => v == null ? 'Selection required' : null,
              ),
            ],
            const SizedBox(height: 32),
            _buildSectionTitle("Message content"),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration("Subject Line", Icons.subject_rounded),
              validator: (v) => v!.isEmpty ? 'Subject is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration("Full Content", Icons.article_rounded),
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Content is required' : null,
            ),
            const SizedBox(height: 32),
            _buildImagePickerZone(isSmall),
            const SizedBox(height: 40),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
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
