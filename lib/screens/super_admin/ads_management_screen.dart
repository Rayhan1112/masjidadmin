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

  // Image Ad State
  XFile? _selectedImage;
  bool _isUploading = false;

  // Full Screen Ad State
  XFile? _selectedFullScreenImage;
  bool _isFullScreenEnabled = false;
  String? _existingFullScreenImageUrl;
  bool _isLoadingFullScreen = true;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFullScreenAdSettings();
  }

  Future<void> _loadFullScreenAdSettings() async {
    try {
      // Fetch the latest full screen ad from the ads collection
      final snapshot = await FirebaseFirestore.instance
          .collection('ads')
          .where('type', isEqualTo: 'full_screen')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          _isFullScreenEnabled = data['isActive'] ?? false;
          _existingFullScreenImageUrl = data['imageUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading full screen ad settings: $e");
    } finally {
      setState(() => _isLoadingFullScreen = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({bool isFullScreen = false}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        if (isFullScreen) {
          _selectedFullScreenImage = pickedFile;
        } else {
          _selectedImage = pickedFile;
        }
      });
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

  Future<void> _saveFullScreenAd() async {
    if (_selectedFullScreenImage == null && _existingFullScreenImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image first.')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      String downloadUrl = _existingFullScreenImageUrl ?? "";

      if (_selectedFullScreenImage != null) {
        final String cloudName = "djlhicadd";
        final String uploadPreset = "mahalaxmi";
        final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        final request = http.MultipartRequest('POST', url)..fields['upload_preset'] = uploadPreset;

        if (kIsWeb) {
          final bytes = await _selectedFullScreenImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: _selectedFullScreenImage!.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath('file', _selectedFullScreenImage!.path));
        }

        final response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonResponse = jsonDecode(responseData);
          downloadUrl = jsonResponse['secure_url'];
        } else {
          throw Exception('Cloudinary upload failed');
        }
      }

      await FirebaseFirestore.instance.collection('ads').add({
        'type': 'full_screen',
        'imageUrl': downloadUrl,
        'isActive': _isFullScreenEnabled,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full Screen Ad published!')));
        setState(() {
          _existingFullScreenImageUrl = downloadUrl;
          _selectedFullScreenImage = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
                    _buildImageAdTab(isSmall),
                    _buildFullScreenAdTab(isSmall),
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
                const Icon(Icons.fullscreen_rounded, size: 20),
                if (!isSmall) const SizedBox(width: 8),
                if (!isSmall) const Text("Full Screen"),
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
                if (!isSmall) const Text("Manage"),
              ],
            ),
          ),
        ],
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

  Widget _buildFullScreenAdTab(bool isSmall) {
    if (_isLoadingFullScreen) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Full Screen Visibility", Icons.visibility_rounded),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text("Enable Full Screen Overlay", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Shows a full-screen image ad when users open the app"),
                value: _isFullScreenEnabled,
                activeColor: const Color(0xFF6366F1),
                onChanged: (val) => setState(() => _isFullScreenEnabled = val),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader("Full Screen Creative", Icons.fullscreen_rounded),
              const SizedBox(height: 20),
              _buildFullScreenPickerZone(),
              const SizedBox(height: 48),
              _buildSubmitButton(
                onPressed: _isUploading ? null : _saveFullScreenAd,
                label: _isUploading ? "Applying Changes..." : "Save Full Screen Settings",
                icon: Icons.save_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenPickerZone() {
    return InkWell(
      onTap: () => _pickImage(isFullScreen: true),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 400,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: _selectedFullScreenImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: kIsWeb 
                    ? Image.network(_selectedFullScreenImage!.path, fit: BoxFit.contain)
                    : Image.file(File(_selectedFullScreenImage!.path), fit: BoxFit.contain),
              )
            : (_existingFullScreenImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(_existingFullScreenImageUrl!, fit: BoxFit.contain, 
                      errorBuilder: (c,e,s) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey))),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 48, color: Color(0xFF6366F1)),
                      SizedBox(height: 16),
                      Text("Select Full Screen Ad Image", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )),
      ),
    );
  }

  Widget _buildImagePickerZone() {
    return InkWell(
      onTap: () => _pickImage(isFullScreen: false),
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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        
        // Sort in memory to avoid index issues
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final timeA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final timeB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA); // Descending
        });

        if (sortedDocs.isEmpty) {
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
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
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
                      child: data['imageUrl'] != null
                          ? Image.network(data['imageUrl'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                          : const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.grey)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type == 'full_screen' ? "FULL SCREEN AD" : "IMAGE AD",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type == 'full_screen' ? "Splash Overlay" : "Visual Campaign",
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
