
import 'package:flutter/material.dart';

class NamazTimingsScreen extends StatefulWidget {
  const NamazTimingsScreen({super.key});

  @override
  State<NamazTimingsScreen> createState() => _NamazTimingsScreenState();
}

class _NamazTimingsScreenState extends State<NamazTimingsScreen> {
  final Map<String, TimeOfDay?> _prayerTimes = {
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Namaz Timings'),
      ),
      body: ListView( // Changed to ListView
        padding: const EdgeInsets.all(24.0),
        children: [
          ..._prayerTimes.keys.map((prayer) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                title: Text(prayer),
                trailing: Text(
                  _prayerTimes[prayer]?.format(context) ?? 'Not set',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _selectTime(context, prayer),
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Save timings
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
