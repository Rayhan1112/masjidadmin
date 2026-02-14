import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class AdsManagementScreen extends StatefulWidget {
  const AdsManagementScreen({super.key});

  @override
  State<AdsManagementScreen> createState() => _AdsManagementScreenState();
}

class _AdsManagementScreenState extends State<AdsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textAdFormKey = GlobalKey<FormState>();

  // Text Ad State
  final _textContentController = TextEditingController();
  double _fontSize = 16.0;
  Color _selectedColor = Colors.black;
  bool _isBold = false;
  bool _isItalic = false;

  // Image Ad State
  XFile? _selectedImage;
  bool _isUploading = false;

  final List<Color> _colorOptions = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textContentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  Future<void> _saveTextAd() async {
    if (!_textAdFormKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    try {
      await FirebaseFirestore.instance.collection('ads').add({
        'type': 'text',
        'content': _textContentController.text,
        'style': {
          'fontSize': _fontSize,
          'color': _selectedColor.value,
          'isBold': _isBold,
          'isItalic': _isItalic,
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Text Ad saved successfully!')));
        _textContentController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving text ad: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveImageAd() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select an image first.')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final String cloudName = "djlhicadd";
      final String uploadPreset = "mahalaxmi";
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await _selectedImage!.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: _selectedImage!.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseData);
        final String downloadUrl = jsonResponse['secure_url'];

        await FirebaseFirestore.instance.collection('ads').add({
          'type': 'image',
          'imageUrl': downloadUrl,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image Ad saved successfully!')));
          setState(() {
            _selectedImage = null;
            _isUploading = false;
          });
        }
      } else {
        throw Exception('Cloudinary upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error saving image ad to Cloudinary: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving image ad: $e')));
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteAd(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Ad"),
        content: const Text("Are you sure you want to remove this advertisement?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('ads').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ad removed successfully!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting ad: $e')));
        }
      }
    }
  }

  Future<void> _toggleAdStatus(String id, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('ads').doc(id).update({
        'isActive': !currentStatus,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating ad status: $e')));
      }
    }
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
              _buildTabBar(isSmall),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTextAdTab(isSmall),
                    _buildImageAdTab(isSmall),
                    _buildManageAdsTab(isSmall),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar(bool isSmall) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6366F1),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF6366F1),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        tabs: [
          Tab(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.text_fields_rounded, size: 20),
                if (!isSmall) const SizedBox(width: 8),
                if (!isSmall) const Text("Text Ad"),
              ],
            ),
          ),
          Tab(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_rounded, size: 20),
                if (!isSmall) const SizedBox(width: 8),
                if (!isSmall) const Text("Image Ad"),
              ],
            ),
          ),
          Tab(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings_suggest_rounded, size: 20),
                if (!isSmall) const SizedBox(width: 8),
                if (!isSmall) const Text("Manage Ads"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextAdTab(bool isSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      child: Form(
        key: _textAdFormKey,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Compose Message", Icons.edit_note_rounded),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _textContentController,
                  maxLines: 4,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Enter the announcement text here...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Content is required" : null,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Display Configuration", Icons.tune_rounded),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      _buildSliderRow("Font Size", _fontSize, (val) => setState(() => _fontSize = val)),
                      const Divider(height: 32),
                      _buildStyleToggles(),
                      const Divider(height: 32),
                      _buildColorPicker(),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Real-time Preview", Icons.visibility_rounded),
                const SizedBox(height: 20),
                _buildPreviewContainer(),
                const SizedBox(height: 40),
                _buildSubmitButton(
                  onPressed: _isUploading ? null : _saveTextAd,
                  label: _isUploading ? "Processing..." : "Deploy Text Ad",
                  icon: Icons.rocket_launch_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(String label, double value, Function(double) onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        const Spacer(),
        SizedBox(
          width: 200,
          child: Slider(
            value: value,
            min: 10,
            max: 40,
            divisions: 30,
            activeColor: const Color(0xFF6366F1),
            onChanged: onChanged,
          ),
        ),
        Text("${value.round()}px", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
      ],
    );
  }

  Widget _buildStyleToggles() {
    return Row(
      children: [
        const Text("Typography Style", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        const Spacer(),
        _buildMiniToggle(label: "Bold", isSelected: _isBold, onToggle: (v) => setState(() => _isBold = v)),
        const SizedBox(width: 12),
        _buildMiniToggle(label: "Italic", isSelected: _isItalic, onToggle: (v) => setState(() => _isItalic = v)),
      ],
    );
  }

  Widget _buildMiniToggle({required String label, required bool isSelected, required Function(bool) onToggle}) {
    return InkWell(
      onTap: () => onToggle(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Accent Color", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _colorOptions.map((color) {
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                    ] : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _textContentController.text.isEmpty
              ? "Announcement text preview will be shown here..."
              : _textContentController.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _fontSize,
            color: _selectedColor,
            fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({required VoidCallback? onPressed, required String label, required IconData icon}) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _isUploading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildImageAdTab(bool isSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Creative Assets", Icons.landscape_rounded),
              const SizedBox(height: 20),
              _buildImagePickerZone(),
              if (_selectedImage != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _selectedImage = null),
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                    label: const Text("Replace this image", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              const SizedBox(height: 48),
              _buildSubmitButton(
                onPressed: _isUploading ? null : _saveImageAd,
                label: _isUploading ? "Uploading..." : "Publish Image Ad",
                icon: Icons.cloud_done_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerZone() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: kIsWeb 
                    ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                    : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        size: 48, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 24),
                  const Text("Click to select advertisement creative",
                      style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text("Supported formats: JPG, PNG",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _buildManageAdsTab(bool isSmall) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text("No active ads found",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(isSmall ? 16 : 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? 'text';

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      color: const Color(0xFFF8FAFC),
                      child: type == 'image'
                          ? Image.network(data['imageUrl'], fit: BoxFit.cover)
                          : const Center(
                              child: Icon(Icons.text_fields_rounded, color: Color(0xFF6366F1))),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type == 'image' ? "IMAGE AD" : "TEXT AD",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type == 'image'
                                  ? "Visual Campaign"
                                  : data['content'] ?? 'No content',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Switch(
                      value: data['isActive'] ?? false,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) => _toggleAdStatus(doc.id, data['isActive'] ?? false),
                    ),
                    IconButton(
                      onPressed: () => _deleteAd(doc.id),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
