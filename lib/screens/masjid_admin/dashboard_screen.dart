import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:masjidadmin/screens/super_admin/create_masjid_screen.dart';
import 'package:masjidadmin/screens/masjid_admin/edit_details_screen.dart';
import 'package:masjidadmin/screens/masjid_admin/edit_location_screen.dart';
import 'package:masjidadmin/screens/masjid_admin/namaz_timings_screen.dart';
import 'package:masjidadmin/services/app_config_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  String _masjidName = 'No Masjid Created';
  String _adminName = 'Admin';
  String _address = '';
  LatLng _location = const LatLng(0, 0);
  Map<String, dynamic> _prayerTimingsV2 = {};
  bool _masjidExists = false;
  bool _isLoadingData = true;
  List<ToolConfig> _enabledTools = [];
  String? _userType;
  Map<String, dynamic>? _todayRoza;
  bool _isRozaLoading = true;

  StreamSubscription? _masjidSubscription;
  StreamSubscription? _adminSubscription;

  @override
  void initState() {
    super.initState();
    if (_userId != null) {
      _fetchData();
      _fetchToolSettings();
      _fetchTodayRoza();
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  void _fetchToolSettings() {
    AppConfigService.getToolConfigStream().listen((tools) {
      if (mounted) {
        setState(() {
          _enabledTools = tools.where((t) => t.isEnabled).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _masjidSubscription?.cancel();
    _adminSubscription?.cancel();
    super.dispose();
  }

  void _fetchData() {
    final adminDoc = FirebaseFirestore.instance.collection('users').doc(_userId);
    _adminSubscription = adminDoc.snapshots().listen((adminSnapshot) {
      if (!mounted) return;
      
      if (adminSnapshot.exists) {
        final adminData = adminSnapshot.data()!;
        setState(() {
          _adminName = adminData['displayName'] ?? 'Admin';
          _userType = adminData['type'];
        });
        
        final masjidId = adminData['masjidId'];
        if (masjidId != null) {
          _fetchMasjidData(masjidId);
        } else {
          // If logged in via email/phone and NOT linked to a masjid yet
          // In your current system, UID was being used as masjidId.
          // Let's fallback to UID if no masjidId linked.
          _fetchMasjidData(_userId!);
        }
      } else {
         setState(() {
          _adminName = 'Admin';
          _isLoadingData = false;
        });
      }
    });
  }

  void _fetchMasjidData(String masjidId) {
    _masjidSubscription?.cancel();
    final masjidDoc = FirebaseFirestore.instance.collection('masjids').doc(masjidId);
    _masjidSubscription = masjidDoc.snapshots().listen((snapshot) async {
      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data()!;
        LatLng newLocation = _location;
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          try {
            newLocation = LatLng(double.parse(data['latitude'].toString()),
                double.parse(data['longitude'].toString()));
          } catch (e) {
            debugPrint("Location Parse Error: $e");
          }
        }

        setState(() {
          _masjidExists = true;
          _masjidName = data['name'] ?? 'Masjid Name';
          _address = data['address'] ?? '';
          _location = newLocation;
          _prayerTimingsV2 = data['prayer_timings_v2'] as Map<String, dynamic>? ?? {};
          _isLoadingData = false;
        });

        if (_mapControllerCompleter.isCompleted) {
          final GoogleMapController controller = await _mapControllerCompleter.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: newLocation, zoom: 15)));
        }
      } else {
        setState(() {
          _masjidExists = false;
          _masjidName = 'No Masjid Created';
          _address = '';
          _location = const LatLng(0, 0);
          _prayerTimingsV2 = {};
          _isLoadingData = false;
        });
      }
    });
  }

  void _navigateToDetailsEditor() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const EditDetailsScreen()));
  }

  void _navigateToTimingsEditor() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const NamazTimingsScreen()));
  }

  void _navigateToLocationEditor() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const EditLocationScreen()));
  }

  Future<void> _fetchTodayRoza() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('ramzan_calendar').get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['schedule'] != null) {
          final List<dynamic> schedule = data['schedule'];
          final now = DateTime.now();
          final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          
          final todayData = schedule.firstWhere(
            (item) {
              final dateStr = item['date'] as String;
              return dateStr.startsWith(todayStr);
            },
            orElse: () => null,
          );

          if (mounted) {
            setState(() {
              _todayRoza = todayData;
              _isRozaLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Error fetching today roza: $e");
    }
    if (mounted) setState(() => _isRozaLoading = false);
  }

  void _navigateToCreateMasjid() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CreateMasjidScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_masjidName),
        centerTitle: true,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _masjidExists
              ? _buildMasjidContent(Theme.of(context))
              : _buildNoMasjidContent(Theme.of(context)),
    );
  }



  Widget _buildMasjidContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        children: [
          if (_userType == 'masjidAdmin' || _userType == 'super_admin') 
            _buildActionCards(theme),
          if (_enabledTools.any((t) => t.id == 'roza_timing')) ...[
            const SizedBox(height: 25),
            _buildRozaCard(theme),
          ],
          if (_enabledTools.where((t) => t.id != 'roza_timing').isNotEmpty) ...[
            const SizedBox(height: 25),
            _buildToolsGrid(theme, excludeRoza: true),
          ],
          const SizedBox(height: 25),
          _buildTimingsCard(theme),
          const SizedBox(height: 25),
          _buildLocationCard(theme),
        ],
      ),
    );
  }

  Widget _buildToolsGrid(ThemeData theme, {bool excludeRoza = false}) {
    final tools = excludeRoza 
      ? _enabledTools.where((t) => t.id != 'roza_timing').toList() 
      : _enabledTools;

    if (tools.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'Quick Tools',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 2.5,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _buildToolCard(theme, tool);
          },
        ),
      ],
    );
  }

  Widget _buildRozaCard(ThemeData theme) {
    if (_isRozaLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_todayRoza == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.restaurant_menu_rounded, color: Colors.white.withOpacity(0.1), size: 100),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TODAY'S ROZA",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          "Ramzan Day ${_todayRoza!['day']}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildRozaTimeItem(
                        "SEHRI ENDS",
                        _todayRoza!['sehri'] ?? '--:--',
                        Icons.wb_twilight_rounded,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                    Expanded(
                      child: _buildRozaTimeItem(
                        "IFTAR STARTS",
                        _todayRoza!['iftar'] ?? '--:--',
                        Icons.nights_stay_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRozaTimeItem(String label, String time, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard(ThemeData theme, ToolConfig tool) {
    return InkWell(
      onTap: () {
        // Handle tool tap
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${tool.label} coming soon!"))
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconForTool(tool.id),
                color: theme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tool.label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTool(String id) {
    switch (id) {
      case 'kaza_namaz': return Icons.calculate_rounded;
      case 'tasbeeh': return Icons.vibration_rounded;
      case 'qibla': return Icons.explore_rounded;
      case 'kids': return Icons.child_care_rounded;
      default: return Icons.build_rounded;
    }
  }

  Widget _buildActionCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniActionCard(
            theme,
            'Edit Profile',
            Icons.edit_note_rounded,
            Colors.orange,
            _navigateToDetailsEditor,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildMiniActionCard(
            theme,
            'Edit Timings',
            Icons.schedule_rounded,
            Colors.indigo,
            _navigateToTimingsEditor,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniActionCard(ThemeData theme, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingsCard(ThemeData theme) {
    final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', 'Jummah'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.access_time_filled_rounded, color: Colors.indigo),
                    SizedBox(width: 10),
                    Text('Prayer Timings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                TextButton(
                  onPressed: _navigateToTimingsEditor,
                  child: const Text('Update'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(flex: 2, child: SizedBox()),
                Expanded(child: Text('Azan', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Namaz', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Akhir', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: prayers.map((p) => _buildTimingRowV2(p, theme)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingRowV2(String prayer, ThemeData theme) {
    final timing = _prayerTimingsV2[prayer] as Map<String, dynamic>? ?? {};
    final azan = _formatDisplayTime(timing['azan']);
    final namaz = _formatDisplayTime(timing['iqamah']);
    final akhir = _formatDisplayTime(timing['akhir']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(prayer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          Expanded(child: Text(azan, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
          Expanded(child: Text(namaz, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.primaryColor, fontWeight: FontWeight.bold))),
          Expanded(child: Text(akhir, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.redAccent))),
        ],
      ),
    );
  }

  String _formatDisplayTime(dynamic timeStr) {
    if (timeStr == null || timeStr is! String || timeStr.isEmpty) return '--:--';
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour < 12 ? 'AM' : 'PM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      // ignore
    }
    return '--:--';
  }

  Widget _buildLocationCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                TextButton(
                  onPressed: _navigateToLocationEditor,
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: GoogleMap(
                key: ValueKey(_location),
                onMapCreated: (controller) {
                  if (!_mapControllerCompleter.isCompleted) {
                    _mapControllerCompleter.complete(controller);
                  }
                },
                initialCameraPosition:
                    CameraPosition(target: _location, zoom: 15),
                markers: {
                  Marker(
                      markerId: const MarkerId('masjid_location'),
                      position: _location)
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.pin_drop_outlined, size: 20, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _address.isEmpty ? 'Loading address...' : _address,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMasjidContent(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mosque_outlined, size: 100, color: theme.primaryColor.withOpacity(0.2)),
            const SizedBox(height: 30),
            const Text(
              'No Masjid Profile Found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please set up your masjid details and location to manage timings.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _navigateToCreateMasjid,
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Create Your Masjid'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
