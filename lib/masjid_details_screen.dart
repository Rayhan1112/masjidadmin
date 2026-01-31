
import 'package:flutter/material.dart';

class MasjidDetailsScreen extends StatefulWidget {
  const MasjidDetailsScreen({super.key});

  @override
  State<MasjidDetailsScreen> createState() => _MasjidDetailsScreenState();
}

class _MasjidDetailsScreenState extends State<MasjidDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _areTimingsChanged = false;

  final Map<String, TimeOfDay> _prayerTimes = {
    'Fajr': const TimeOfDay(hour: 5, minute: 0),
    'Dhuhr': const TimeOfDay(hour: 13, minute: 0),
    'Asr': const TimeOfDay(hour: 16, minute: 0),
    'Maghrib': const TimeOfDay(hour: 18, minute: 30),
    'Isha': const TimeOfDay(hour: 20, minute: 0),
    'Jummah': const TimeOfDay(hour: 13, minute: 0),
  };

  Future<void> _selectTime(BuildContext context, String prayer) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _prayerTimes[prayer] ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _prayerTimes[prayer]) {
      setState(() {
        _prayerTimes[prayer] = picked;
        _areTimingsChanged = true;
      });
    }
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masjid Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Masjid Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the Masjid name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildPrayerTimes(context),
              const SizedBox(height: 24),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map, semanticLabel: "Get Current Location"),
                    onPressed: () {
                      // TODO: Add geolocator package to get current location
                      setState(() {
                        _latitudeController.text = '24.8607';
                        _longitudeController.text = '67.0011';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Save details
                  }
                },
                child: const Text('Save All Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTimes(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Prayer Timings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: _prayerTimes.entries.map((entry) {
              return ListTile(
                title: Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                trailing: Text(entry.value.format(context), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                onTap: () => _selectTime(context, entry.key),
              );
            }).toList(),
          ),
        ),
        if (_areTimingsChanged)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton(
              onPressed: () {
                // Logic to save timings
                setState(() {
                  _areTimingsChanged = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Timings saved!')),
                );
              },
              child: const Text('Save Time'),
            ),
          ),
      ],
    );
  }
}
