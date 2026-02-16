import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:masjidadmin/screens/masjid_admin/masjid_details_screen.dart';

class AllMasjidsScreen extends StatefulWidget {
  const AllMasjidsScreen({super.key});

  @override
  State<AllMasjidsScreen> createState() => _AllMasjidsScreenState();
}

class _AllMasjidsScreenState extends State<AllMasjidsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _searchQuery = "";
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _generateIncrementalId() async {
    final snapshot = await FirebaseFirestore.instance.collection('masjids').get();
    int maxNum = 0;
    final regex = RegExp(r'^Sangli(\d+)$');
    
    for (var doc in snapshot.docs) {
      final match = regex.firstMatch(doc.id);
      if (match != null) {
        final num = int.tryParse(match.group(1)!);
        if (num != null && num > maxNum) {
          maxNum = num;
        }
      }
    }
    return 'Sangli${maxNum + 1}';
  }

  Future<void> _createMasjid() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final masjidId = await _generateIncrementalId();
      final docRef = FirebaseFirestore.instance.collection('masjids').doc(masjidId);
      
      final doc = await docRef.get();
      if (doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Masjid ID already exists!'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isCreating = false);
        return;
      }

      await docRef.set({
        'name': _nameController.text.trim(),
        'id': masjidId,
        'password': _passwordController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'address': 'Address not set yet',
        'latitude': '0',
        'longitude': '0',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Masjid created with ID: $masjidId'), backgroundColor: Colors.green),
        );
      }
      _nameController.clear();
      _passwordController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating masjid: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.add_business_rounded, color: Color(0xFF4A90E2)),
              SizedBox(width: 12),
              Text('Create New Masjid', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration("Masjid Name", Icons.mosque),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 8),
                  const Text("ID will be auto-generated (e.g. Sangli1, Sangli2)", 
                    style: TextStyle(fontSize: 10, color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: _inputDecoration("Access Password", Icons.lock_outline),
                    obscureText: true,
                    validator: (v) => v!.length < 6 ? 'Password must be at least 6 chars' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: _isCreating ? null : () async {
                setDialogState(() => _isCreating = true);
                await _createMasjid();
                setDialogState(() => _isCreating = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCreating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4A90E2), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4A90E2))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double padding = width < 600 ? 16 : 24;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateDialog,
            backgroundColor: const Color(0xFF4A90E2),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('ADD MASJID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(width),
                const SizedBox(height: 20),
                Expanded(child: _buildMasjidsList(width)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(double screenWidth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: screenWidth < 400 ? "Search..." : "Search by name or city...",
          prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMasjidsList(double screenWidth) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('masjids').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs;

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final address = (data['address'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || address.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mosque_outlined, size: 60, color: Colors.grey[200]),
                const SizedBox(height: 10),
                Text(
                  _searchQuery.isEmpty ? "No Masjids found" : "No results found",
                  style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        // Use GridView for wider screens
        if (screenWidth > 900) {
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3.5,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildMasjidCard(doc.data() as Map<String, dynamic>, doc.id, screenWidth);
            },
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _buildMasjidCard(doc.data() as Map<String, dynamic>, doc.id, screenWidth);
          },
        );
      },
    );
  }

  Widget _buildMasjidCard(Map<String, dynamic> data, String masjidId, double screenWidth) {
    final bool isCompact = screenWidth < 400;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MasjidDetailsScreen(
                  masjidData: data,
                  masjidId: masjidId,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 8 : 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.mosque, color: const Color(0xFF4A90E2), size: isCompact ? 20 : 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data['name'] ?? 'Unknown Masjid',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: isCompact ? 14 : 17,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "ID: ${data['id'] ?? masjidId}",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: isCompact ? 12 : 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['address'] ?? 'No address',
                              style: TextStyle(color: Colors.grey[500], fontSize: isCompact ? 11 : 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: isCompact ? 14 : 18, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
