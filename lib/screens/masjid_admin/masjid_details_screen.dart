import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MasjidDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> masjidData;
  final String masjidId;

  const MasjidDetailsScreen({
    super.key,
    required this.masjidData,
    required this.masjidId,
  });

  Future<void> _openInMaps(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timings = masjidData['prayer_timings_v2'] as Map<String, dynamic>? ?? {};
    final double lat = double.tryParse(masjidData['latitude']?.toString() ?? '0') ?? 0;
    final double lng = double.tryParse(masjidData['longitude']?.toString() ?? '0') ?? 0;
    final LatLng location = LatLng(lat, lng);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(masjidData['name'] ?? 'Masjid Details', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddressSection(
                      context,
                      masjidData['address'] ?? 'No address provided',
                      lat,
                      lng),
                  const SizedBox(height: 25),
                  const Text('Prayer Timings',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 15),
                  _buildTimingsTable(timings, theme),
                  const SizedBox(height: 30),
                  const Text('Location Map',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 15),
                  _buildMapSection(location),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context, String address, double lat, double lng) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Address", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(address, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openInMaps(lat, lng),
              icon: const Icon(Icons.directions_rounded),
              label: const Text("LOCATE ON GOOGLE MAPS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingsTable(Map<String, dynamic> timings, ThemeData theme) {
    final List<String> prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', 'Jummah'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Prayer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                Expanded(child: Text('Azan', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                Expanded(child: Text('Namaz', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                Expanded(child: Text('Akhir', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
              ],
            ),
          ),
          ...prayerOrder.map((p) => _buildTimingRow(p, timings[p], theme)).toList(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildTimingRow(String prayer, dynamic timingData, ThemeData theme) {
    final Map<String, dynamic> timing = (timingData as Map<String, dynamic>?) ?? {};
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(prayer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Expanded(child: Text(_formatTime(timing['azan']), textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontSize: 13))),
          Expanded(child: Text(_formatTime(timing['iqamah']), textAlign: TextAlign.center, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(child: Text(_formatTime(timing['akhir']), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        ],
      ),
    );
  }

  String _formatTime(dynamic timeStr) {
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
    } catch (e) {}
    return '--:--';
  }

  Widget _buildMapSection(LatLng location) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: location, zoom: 15),
          markers: {
            Marker(markerId: const MarkerId('masjid_loc'), position: location),
          },
          zoomControlsEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          scrollGesturesEnabled: true,
          mapToolbarEnabled: true,
        ),
      ),
    );
  }
}
