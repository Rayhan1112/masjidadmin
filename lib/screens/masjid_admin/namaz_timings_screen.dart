import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrayerTiming {
  TimeOfDay? azan;
  TimeOfDay? iqamah;
  TimeOfDay? akhir;

  PrayerTiming({this.azan, this.iqamah, this.akhir});

  Map<String, String> toMap() {
    return {
      'azan': _formatTime(azan),
      'iqamah': _formatTime(iqamah),
      'akhir': _formatTime(akhir),
    };
  }

  static PrayerTiming fromMap(Map<String, dynamic> map) {
    return PrayerTiming(
      azan: _parseTime(map['azan']),
      iqamah: _parseTime(map['iqamah']),
      akhir: _parseTime(map['akhir']),
    );
  }

  static String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay? _parseTime(dynamic timeStr) {
    if (timeStr == null || timeStr is! String || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      debugPrint('Error parsing time: $timeStr');
    }
    return null;
  }
}

class NamazTimingsScreen extends StatefulWidget {
  const NamazTimingsScreen({super.key});

  @override
  State<NamazTimingsScreen> createState() => _NamazTimingsScreenState();
}

class _NamazTimingsScreenState extends State<NamazTimingsScreen> {
  final List<String> _prayerNames = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
    'Jummah',
  ];

  Map<String, PrayerTiming> _prayerTimings = {};
  Map<String, PrayerTiming> _originalTimings = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _masjidId;
  String _masjidName = '';

  final CollectionReference _notificationsRef =
      FirebaseFirestore.instance.collection('notification_requests');

  @override
  void initState() {
    super.initState();
    for (var name in _prayerNames) {
      _prayerTimings[name] = PrayerTiming();
    }
    _loadTimings();
  }

  Future<void> _loadTimings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Get the Masjid ID linked to this admin
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
      if (adminDoc.exists) {
        _masjidId = adminDoc.data()?['masjidId'];
      }
      
      // Fallback for older accounts or direct UID linking
      _masjidId ??= user.uid;

      // 2. Load masjid timings
      final docRef = FirebaseFirestore.instance.collection('masjids').doc(_masjidId);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _masjidName = data['name'] ?? 'Masjid';

        final timingsData = data['prayer_timings_v2'] as Map<String, dynamic>?;
        if (timingsData != null) {
          setState(() {
            for (var name in _prayerNames) {
              if (timingsData.containsKey(name)) {
                _prayerTimings[name] = PrayerTiming.fromMap(timingsData[name]);
              }
            }
          });
        } else {
          // Fallback to old format if exist
          final oldTimings = data['prayerTimes'] as String?;
          if (oldTimings != null && oldTimings.isNotEmpty) {
            final times = oldTimings.split(',');
            setState(() {
              for (int i = 0; i < times.length && i < _prayerNames.length; i++) {
                _prayerTimings[_prayerNames[i]]?.iqamah = _parseTime(times[i]);
              }
            });
          }
        }
        
        // Deep copy for original timings
        _originalTimings = {};
        _prayerTimings.forEach((key, value) {
          _originalTimings[key] = PrayerTiming(
            azan: value.azan,
            iqamah: value.iqamah,
            akhir: value.akhir,
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading timings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      debugPrint('Error parsing time: $timeStr');
    }
    return null;
  }

  String _formatTimeWithAMPM(TimeOfDay? time) {
    if (time == null) return 'Not set';
    final period = time.hour < 12 ? 'AM' : 'PM';
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _selectTime(BuildContext context, String prayerName, String type) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (type == 'azan') initialTime = _prayerTimings[prayerName]?.azan ?? TimeOfDay.now();
    if (type == 'iqamah') initialTime = _prayerTimings[prayerName]?.iqamah ?? TimeOfDay.now();
    if (type == 'akhir') initialTime = _prayerTimings[prayerName]?.akhir ?? TimeOfDay.now();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (type == 'azan') _prayerTimings[prayerName]?.azan = picked;
        if (type == 'iqamah') _prayerTimings[prayerName]?.iqamah = picked;
        if (type == 'akhir') _prayerTimings[prayerName]?.akhir = picked;
      });
    }
  }

  Future<void> _saveTimings() async {
    if (_masjidId == null) return;

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updateData = {};
      final Map<String, dynamic> timingsMap = {};
      
      final List<String> changedPrayers = [];
      
      for (var name in _prayerNames) {
        final current = _prayerTimings[name]!;
        final original = _originalTimings[name];
        
        timingsMap[name] = current.toMap();
        
        if (original == null || 
            current.azan != original.azan || 
            current.iqamah != original.iqamah || 
            current.akhir != original.akhir) {
          changedPrayers.add(name);
        }
      }

      updateData['prayer_timings_v2'] = timingsMap;
      updateData['lastUpdated'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('masjids').doc(_masjidId).update(updateData);

      if (changedPrayers.isNotEmpty) {
        await _sendNotification(changedPrayers);
      }

      // Update original timings
      _prayerTimings.forEach((key, value) {
        _originalTimings[key] = PrayerTiming(
          azan: value.azan,
          iqamah: value.iqamah,
          akhir: value.akhir,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timings saved and users notified!')),
        );
      }
    } catch (e) {
      debugPrint('Error saving timings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendNotification(List<String> changedPrayers) async {
    try {
      for (var prayerName in changedPrayers) {
        final timing = _prayerTimings[prayerName]!;
        final azan = _formatTimeWithAMPM(timing.azan);
        final jamat = _formatTimeWithAMPM(timing.iqamah);
        final akhir = _formatTimeWithAMPM(timing.akhir);

        await _notificationsRef.add({
          'title': '$prayerName - $jamat',
          'body': 'Azan: $azan | Jamat: $jamat | Akhir: $akhir',
          'sentAt': FieldValue.serverTimestamp(),
          'sentBy': _masjidName,
          'target': 'all_users',
          'status': 'pending',
          'type': 'timing_change',
          'masjidId': _masjidId,
        });
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  itemCount: _prayerNames.length,
                  itemBuilder: (context, index) {
                    final name = _prayerNames[index];
                    return _buildPrayerCard(name);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 56,
        margin: const EdgeInsets.only(bottom: 10),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveTimings,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 4,
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded),
                    SizedBox(width: 8),
                    Text('SAVE & NOTIFY ALL',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPrayerCard(String prayerName) {
    final timing = _prayerTimings[prayerName]!;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_filled_rounded, color: theme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  prayerName,
                  style: TextStyle(color: theme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (prayerName == 'Jummah')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Weekly', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildTimePickerItem(
                  context,
                  'AZAN',
                  timing.azan,
                  Icons.notifications_active_outlined,
                  () => _selectTime(context, prayerName, 'azan'),
                ),
                _buildDivider(),
                _buildTimePickerItem(
                  context,
                  'NAMAZ',
                  timing.iqamah,
                  Icons.mosque_outlined,
                  () => _selectTime(context, prayerName, 'iqamah'),
                  isMain: true,
                ),
                _buildDivider(),
                _buildTimePickerItem(
                  context,
                  'AKHIR',
                  timing.akhir,
                  Icons.timer_off_outlined,
                  () => _selectTime(context, prayerName, 'akhir'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  Widget _buildTimePickerItem(
    BuildContext context,
    String label,
    TimeOfDay? time,
    IconData icon,
    VoidCallback onTap, {
    bool isMain = false,
  }) {
    final theme = Theme.of(context);
    final isSet = time != null;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSet ? (isMain ? theme.primaryColor : Colors.blueGrey) : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(
              isSet ? _formatTimeWithAMPM(time) : '--:--',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isMain ? FontWeight.bold : FontWeight.w600,
                color: isSet ? (isMain ? theme.primaryColor : Colors.black87) : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
