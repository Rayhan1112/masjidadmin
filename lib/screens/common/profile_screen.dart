import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masjidadmin/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _emailController.text = user.email ?? 'No email associated';

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data() != null && mounted) {
      final data = snapshot.data()!;
      _nameController.text = data['displayName'] ?? user.displayName ?? '';
      _phoneController.text = data['phone'] ?? '';
    } else if (mounted) {
      _nameController.text = user.displayName ?? '';
      _phoneController.text = '';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update display name in Firebase Auth
      if (user.displayName != _nameController.text) {
        await user.updateDisplayName(_nameController.text);
      }
      
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await docRef.update({
        'displayName': _nameController.text,
        'phone':
            _phoneController.text.isNotEmpty ? _phoneController.text : null,
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e")));
    } finally {
      if (mounted) {
        setState(() => _isEditing = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Container(
            color: const Color(0xFFF5F7FA),
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Profile Settings",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Manage your personal details and account info",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildProfileActionsCard(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }



  Widget _buildProfileActionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileTextField(
                controller: _nameController,
                icon: Icons.person_outline,
                label: 'Name'),
            const SizedBox(height: 12),
            _buildProfileTextField(
                controller: _emailController,
                icon: Icons.email_outlined,
                label: 'Email',
                readOnly: true),
            const SizedBox(height: 12),
            _buildProfileTextField(
                controller: _phoneController,
                icon: Icons.phone_outlined,
                label: _phoneController.text.isNotEmpty
                    ? 'Phone'
                    : 'No number added'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_isEditing) {
                        _saveProfile();
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
                    icon: Icon(_isEditing ? Icons.save_outlined : Icons.edit,
                        size: 18),
                    label: Text(_isEditing ? 'Save' : 'Edit',
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Change Password functionality not implemented yet.')));
                    },
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: const Text('Password',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _authService.signOut(),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTextField(
      {required TextEditingController controller,
      required IconData icon,
      required String label,
      bool readOnly = false}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly || !_isEditing,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        hintText: label == 'No number added' ? label : null,
        filled: readOnly || !_isEditing,
        fillColor: readOnly || !_isEditing ? Colors.grey[200] : Colors.transparent,
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    );
  }
}
