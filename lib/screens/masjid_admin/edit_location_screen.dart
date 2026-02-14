import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:masjidadmin/screens/common/location_result.dart';
import 'package:masjidadmin/screens/common/map_picker_screen.dart';

class EditLocationScreen extends StatefulWidget {
  const EditLocationScreen({super.key});

  @override
  _EditLocationScreenState createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends State<EditLocationScreen> {
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('masjids').doc(user.uid);
    final snapshot = await docRef.get();

    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      _addressController.text = data['address'] ?? '';
      _latitudeController.text = data['latitude'] ?? '';
      _longitudeController.text = data['longitude'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _openMapPicker() async {
    LatLng? initialLocation;
    if (_latitudeController.text.isNotEmpty &&
        _longitudeController.text.isNotEmpty) {
      try {
        initialLocation = LatLng(double.parse(_latitudeController.text),
            double.parse(_longitudeController.text));
      } catch (e) {}
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (ctx) => MapPickerScreen(initialLocation: initialLocation)),
    );

    if (result != null && result is LocationResult) {
      setState(() {
        _latitudeController.text = result.latitude.toString();
        _longitudeController.text = result.longitude.toString();
        _addressController.text = result.address;
      });
    }
  }

  Future<void> _saveLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('masjids').doc(user.uid);

    try {
      await docRef.update({
        'address': _addressController.text,
        'latitude': _latitudeController.text,
        'longitude': _longitudeController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location saved successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save location: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _isLoading ? const Center(child: CircularProgressIndicator()) : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openMapPicker,
                          icon: const Icon(Icons.map),
                          label: const Text('Select Location on Map'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 3,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter an address'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: _latitudeController,
                                  decoration: const InputDecoration(
                                      labelText: 'Latitude'),
                                  readOnly: true)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: TextFormField(
                                  controller: _longitudeController,
                                  decoration: const InputDecoration(
                                      labelText: 'Longitude'),
                                  readOnly: true)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: _saveLocation,
                            child: const Text('Save Location')),
                      ),
                    ],
                  ),
                );
              },
            ),
        ),
      ),
    );
  }
}
