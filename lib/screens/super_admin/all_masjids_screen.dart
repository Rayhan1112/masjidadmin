import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  Future<void> _createMasjid({String? address, String? latitude, String? longitude}) async {
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
        'address': address?.isNotEmpty == true ? address : 'Address not set yet',
        'latitude': latitude?.isNotEmpty == true ? latitude : '0',
        'longitude': longitude?.isNotEmpty == true ? longitude : '0',
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
    final addressController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    bool isFetchingLocation = false;

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
          content: SizedBox(
            width: 700,
            child: Form(
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: _inputDecoration("Full Address", Icons.location_on),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: latController,
                            decoration: _inputDecoration("Latitude", Icons.gps_fixed),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lngController,
                            decoration: _inputDecoration("Longitude", Icons.gps_fixed),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isFetchingLocation ? null : () async {
                          setDialogState(() => isFetchingLocation = true);
                          try {
                            final position = await _getCurrentGPSPosition();
                            if (position != null) {
                              latController.text = position.latitude.toString();
                              lngController.text = position.longitude.toString();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('GPS coordinates captured!'), backgroundColor: Colors.green),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setDialogState(() => isFetchingLocation = false);
                          }
                        },
                        icon: isFetchingLocation 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded),
                        label: Text(isFetchingLocation ? 'FETCHING GPS...' : 'GET CURRENT LOCATION'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4A90E2),
                          side: const BorderSide(color: Color(0xFF4A90E2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
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
                await _createMasjid(
                  address: addressController.text.trim(),
                  latitude: latController.text.trim(),
                  longitude: lngController.text.trim(),
                );
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

        if (screenWidth > 900) {
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3.0,
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

  Future<void> _deleteMasjid(String masjidId) async {
    // Check for linked admin
    final adminQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('masjidId', isEqualTo: masjidId)
        .limit(1)
        .get();
    
    final bool hasAdmin = adminQuery.docs.isNotEmpty;
    final adminData = hasAdmin ? adminQuery.docs.first.data() : null;
    final String? adminUid = hasAdmin ? adminQuery.docs.first.id : null;
    final String? adminName = hasAdmin ? adminData!['displayName'] : null;

    final String? choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: hasAdmin ? Colors.orange : Colors.red),
            const SizedBox(width: 10),
            const Text("Delete Masjid?"),
          ],
        ),
        content: Text(hasAdmin 
          ? "This masjid has a linked admin: $adminName.\n\nWhat would you like to delete?"
          : "Are you sure you want to delete this masjid and all its data?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, 'masjid'), 
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(hasAdmin ? "DELETE MASJID ONLY" : "DELETE"),
          ),
          if (hasAdmin)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'both'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("DELETE MASJID & ADMIN"),
            ),
        ],
      ),
    );

    if (choice == 'masjid' || choice == 'both') {
      try {
        await FirebaseFirestore.instance.collection('masjids').doc(masjidId).delete();
        if (choice == 'both' && adminUid != null) {
          await FirebaseFirestore.instance.collection('admins').doc(adminUid).delete();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(choice == 'both' ? "Masjid and Admin deleted" : "Masjid deleted successfully"), 
              backgroundColor: Colors.green
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showEditMasjidDialog(Map<String, dynamic> data, String masjidId) {
    _nameController.text = data['name'] ?? '';
    final addressController = TextEditingController(text: data['address'] ?? '');
    final latController = TextEditingController(text: data['latitude']?.toString() ?? '');
    final lngController = TextEditingController(text: data['longitude']?.toString() ?? '');
    bool isFetchingLocation = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Edit Masjid', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration("Masjid Name", Icons.mosque),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: _inputDecoration("Address", Icons.location_on_outlined),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          decoration: _inputDecoration("Latitude", Icons.gps_fixed),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: lngController,
                          decoration: _inputDecoration("Longitude", Icons.gps_fixed),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isFetchingLocation ? null : () async {
                        setDialogState(() => isFetchingLocation = true);
                        try {
                          final position = await _getCurrentGPSPosition();
                          if (position != null) {
                            latController.text = position.latitude.toString();
                            lngController.text = position.longitude.toString();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('GPS coordinates captured!'), backgroundColor: Colors.green),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setDialogState(() => isFetchingLocation = false);
                        }
                      },
                      icon: isFetchingLocation 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                      label: Text(isFetchingLocation ? 'FETCHING GPS...' : 'GET CURRENT LOCATION'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A90E2),
                        side: const BorderSide(color: Color(0xFF4A90E2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('masjids').doc(masjidId).update({
                  'name': _nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'latitude': latController.text.trim(),
                  'longitude': lngController.text.trim(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
                _nameController.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('UPDATE'),
            ),
          ],
        ),
      ),
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
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showEditMasjidDialog(data, masjidId),
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                      tooltip: "Edit Masjid",
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteMasjid(masjidId),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      tooltip: "Delete Masjid",
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: isCompact ? 12 : 14, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Position?> _getCurrentGPSPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied. Please enable in settings.';
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      rethrow;
    }
  }
}
