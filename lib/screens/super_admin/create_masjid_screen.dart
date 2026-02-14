import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:masjidadmin/screens/common/location_result.dart';
import 'package:masjidadmin/screens/common/map_picker_screen.dart';

class PrayerTimingInfo {
  TimeOfDay? azan;
  TimeOfDay? iqamah;
  TimeOfDay? akhir;

  PrayerTimingInfo({this.azan, this.iqamah, this.akhir});

  Map<String, String> toMap() {
    return {
      'azan': _formatTime(azan),
      'iqamah': _formatTime(iqamah),
      'akhir': _formatTime(akhir),
    };
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class CreateMasjidScreen extends StatefulWidget {
  const CreateMasjidScreen({super.key});

  @override
  State<CreateMasjidScreen> createState() => _CreateMasjidScreenState();
}

class _CreateMasjidScreenState extends State<CreateMasjidScreen> {
  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  final _masjidNameController = TextEditingController();
  LatLng? _selectedLatLng;
  String _selectedAddress = '';

  final Map<String, PrayerTimingInfo> _prayerTimings = {
    'Fajr': PrayerTimingInfo(azan: const TimeOfDay(hour: 4, minute: 30), iqamah: const TimeOfDay(hour: 5, minute: 0)),
    'Dhuhr': PrayerTimingInfo(azan: const TimeOfDay(hour: 12, minute: 30), iqamah: const TimeOfDay(hour: 13, minute: 0)),
    'Asr': PrayerTimingInfo(azan: const TimeOfDay(hour: 15, minute: 30), iqamah: const TimeOfDay(hour: 16, minute: 0)),
    'Maghrib': PrayerTimingInfo(azan: const TimeOfDay(hour: 18, minute: 20), iqamah: const TimeOfDay(hour: 18, minute: 30)),
    'Isha': PrayerTimingInfo(azan: const TimeOfDay(hour: 19, minute: 30), iqamah: const TimeOfDay(hour: 20, minute: 0)),
    'Jummah': PrayerTimingInfo(azan: const TimeOfDay(hour: 12, minute: 30), iqamah: const TimeOfDay(hour: 13, minute: 30)),
  };

  final _zimmedarNameController = TextEditingController();
  final _zimmedarPhoneController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdminDetails();
  }

  Future<void> _loadAdminDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance.collection('admins').doc(user.uid);
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        _zimmedarNameController.text =
            data['displayName'] ?? user.displayName ?? '';
        _zimmedarPhoneController.text = data['phone'] ?? '';
      } else {
        _zimmedarNameController.text = user.displayName ?? '';
      }
    }
  }

  Future<void> _openMapPicker() async {
    final LocationResult? result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const MapPickerScreen()),
    );

    if (result != null) {
      setState(() {
        _selectedLatLng = LatLng(result.latitude, result.longitude);
        _selectedAddress = result.address;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, String prayer, String type) async {
    TimeOfDay initial = TimeOfDay.now();
    if (type == 'azan') initial = _prayerTimings[prayer]?.azan ?? initial;
    if (type == 'iqamah') initial = _prayerTimings[prayer]?.iqamah ?? initial;
    if (type == 'akhir') initial = _prayerTimings[prayer]?.akhir ?? initial;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (type == 'azan') _prayerTimings[prayer]?.azan = picked;
        if (type == 'iqamah') _prayerTimings[prayer]?.iqamah = picked;
        if (type == 'akhir') _prayerTimings[prayer]?.akhir = picked;
      });
    }
  }

  Future<void> _saveMasjidData() async {
    if (!_formKeyStep3.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No admin user logged in.')));
      setState(() => _isLoading = false);
      return;
    }

    if (_selectedLatLng == null || _selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a location on the map.')));
      setState(() => _isLoading = false);
      return;
    }

    final masjidDocRef = FirebaseFirestore.instance.collection('masjids').doc(user.uid);
    
    final Map<String, dynamic> timingsMap = {};
    _prayerTimings.forEach((key, value) {
      timingsMap[key] = value.toMap();
    });

    try {
      final Map<String, dynamic> masjidData = {
        'name': _masjidNameController.text.trim(),
        'address': _selectedAddress,
        'latitude': _selectedLatLng!.latitude.toString(),
        'longitude': _selectedLatLng!.longitude.toString(),
        'prayer_timings_v2': timingsMap,
        'subscriberCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await masjidDocRef.set(masjidData, SetOptions(merge: true));

      final adminDocRef = FirebaseFirestore.instance.collection('admins').doc(user.uid);
      await adminDocRef.set({
        'displayName': _zimmedarNameController.text.trim(),
        'phone': _zimmedarPhoneController.text.trim().isNotEmpty
            ? _zimmedarPhoneController.text.trim()
            : null,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Color(0xFF10B981), content: Text('Masjid created successfully!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Failed to create masjid: $e')));
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _masjidNameController.dispose();
    _zimmedarNameController.dispose();
    _zimmedarPhoneController.dispose();
    super.dispose();
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
              _buildProgressIndicator(isSmall),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmall ? 16 : 32),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildCurrentStepView(isSmall),
                    ),
                  ),
                ),
              ),
              _buildNavigationButtons(isSmall),
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
            child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF6366F1), size: 24),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Register Masjid",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                "Add a new community center to the system",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isSmall) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildProgressStep(0, "Basic Info", isSmall),
          _buildProgressStep(1, "Timings", isSmall),
          _buildProgressStep(2, "Management", isSmall),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isSmall) {
    final bool isActive = _currentStep == step;
    final bool isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isActive || isCompleted ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCompleted)
                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF6366F1))
              else
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      "${step + 1}",
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              if (!isSmall) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView(bool isSmall) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(isSmall);
      case 1:
        return _buildStep2(isSmall);
      case 2:
        return _buildStep3(isSmall);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(bool isSmall) {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionSubHeader("Identity"),
          const SizedBox(height: 16),
          TextFormField(
            controller: _masjidNameController,
            decoration: _inputDecoration("Masjid Name", Icons.mosque_rounded),
            validator: (v) => v!.isEmpty ? 'Masjid name is required' : null,
          ),
          const SizedBox(height: 32),
          _buildSectionSubHeader("Location"),
          const SizedBox(height: 16),
          _buildLocationPickerUI(),
          if (_selectedLatLng != null) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200)),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _selectedLatLng!, zoom: 15),
                  markers: {Marker(markerId: const MarkerId('m1'), position: _selectedLatLng!)},
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionSubHeader("Official Prayer Timings"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: _prayerTimings.keys.map((prayer) => _buildPrayerRow(prayer)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(bool isSmall) {
    return Form(
      key: _formKeyStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionSubHeader("Administrator Details"),
          const SizedBox(height: 16),
          TextFormField(
            controller: _zimmedarNameController,
            decoration: _inputDecoration("Full Name", Icons.person_rounded),
            validator: (v) => v!.isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _zimmedarPhoneController,
            decoration: _inputDecoration("Phone Number", Icons.phone_rounded),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 32),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildSectionSubHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 1.1),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    );
  }

  Widget _buildLocationPickerUI() {
    return InkWell(
      onTap: _openMapPicker,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _selectedLatLng == null ? Colors.red.withOpacity(0.2) : Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.05), shape: BoxShape.circle),
              child: const Icon(Icons.map_rounded, color: Color(0xFF6366F1), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedAddress.isEmpty ? "Pin Masjid Location on Map" : _selectedAddress,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: _selectedAddress.isEmpty ? FontWeight.w500 : FontWeight.bold,
                color: _selectedAddress.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text("Click to select pinpoint coordinates", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRow(String prayer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade50)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(prayer, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ),
          const Spacer(),
          _buildTimeChip(prayer, 'azan'),
          const SizedBox(width: 8),
          _buildTimeChip(prayer, 'iqamah'),
          const SizedBox(width: 8),
          _buildTimeChip(prayer, 'akhir'),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String prayer, String type) {
    TimeOfDay? time;
    IconData icon;
    Color color;
    String label;

    if (type == 'azan') {
      time = _prayerTimings[prayer]?.azan;
      icon = Icons.volume_up_rounded;
      color = const Color(0xFF6366F1);
      label = "Azan";
    } else if (type == 'iqamah') {
      time = _prayerTimings[prayer]?.iqamah;
      icon = Icons.access_time_filled_rounded;
      color = const Color(0xFFF59E0B);
      label = "Jamat";
    } else {
      time = _prayerTimings[prayer]?.akhir;
      icon = Icons.timer_off_rounded;
      color = const Color(0xFF94A3B8);
      label = "End";
    }

    return Expanded(
      child: InkWell(
        onTap: () => _selectTime(context, prayer, type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                time?.format(context) ?? "--:--",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "By creating this masjid, you will be assigned as its primary administrator. You can change this later.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmall ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Text("Previous", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_currentStep == 2 ? "COMPLETE REGISTRATION" : "Next Step", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (_formKeyStep1.currentState!.validate()) {
        if (_selectedLatLng == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select masjid location on map")));
          return;
        }
        setState(() => _currentStep++);
      }
    } else if (_currentStep == 1) {
      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
      if (_formKeyStep3.currentState!.validate()) {
        _saveMasjidData();
      }
    }
  }
}
