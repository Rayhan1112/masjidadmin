import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_api_service.dart';

class CalendarDay {
  final int day;
  final DateTime date;
  String sehri;
  String iftar;

  CalendarDay({required this.day, required this.date, this.sehri = "", this.iftar = ""});

  Map<String, dynamic> toMap() => {
    'day': day,
    'date': date.toIso8601String(),
    'sehri': sehri,
    'iftar': iftar,
  };
}

class RamzanCalendarScreen extends StatefulWidget {
  const RamzanCalendarScreen({super.key});

  @override
  State<RamzanCalendarScreen> createState() => _RamzanCalendarScreenState();
}

class _RamzanCalendarScreenState extends State<RamzanCalendarScreen> {
  late List<CalendarDay> _days;
  late List<TextEditingController> _sehriControllers;
  late List<TextEditingController> _iftarControllers;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeDays();
    _fetchCalendarData();
  }

  void _initializeDays() {
    // Current year's Ramzan start date (approx Feb 19, 2026)
    DateTime start = DateTime(2026, 2, 19);
    DateTime end = DateTime(2026, 3, 20); 
    
    _days = [];
    int dayCount = 1;
    for (DateTime d = start; d.isBefore(end.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
      _days.add(CalendarDay(day: dayCount++, date: d));
    }

    _sehriControllers = List.generate(_days.length, (i) => TextEditingController());
    _iftarControllers = List.generate(_days.length, (i) => TextEditingController());
  }

  Future<void> _fetchCalendarData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('ramzan_calendar').get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['schedule'] != null) {
          final List<dynamic> schedule = data['schedule'];
          
          setState(() {
            for (var item in schedule) {
              int dayIndex = (item['day'] as int) - 1;
              if (dayIndex >= 0 && dayIndex < _days.length) {
                _sehriControllers[dayIndex].text = item['sehri'] ?? "";
                _iftarControllers[dayIndex].text = item['iftar'] ?? "";
                _days[dayIndex].sehri = item['sehri'] ?? "";
                _days[dayIndex].iftar = item['iftar'] ?? "";
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching calendar data: $e");
    }
  }

  @override
  void dispose() {
    for (var c in _sehriControllers) {
      c.dispose();
    }
    for (var c in _iftarControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller, bool isSehri) async {
    TimeOfDay initialTime;
    if (controller.text.isNotEmpty) {
      try {
        final format = DateFormat('hh:mm a');
        final dt = format.parse(controller.text);
        initialTime = TimeOfDay.fromDateTime(dt);
      } catch (e) {
        initialTime = isSehri ? const TimeOfDay(hour: 5, minute: 0) : const TimeOfDay(hour: 18, minute: 30);
      }
    } else {
      initialTime = isSehri ? const TimeOfDay(hour: 5, minute: 0) : const TimeOfDay(hour: 18, minute: 30);
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6366F1),
                onPrimary: Colors.white,
                onSurface: Color(0xFF1E293B),
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final format = DateFormat('hh:mm a');
      controller.text = format.format(dt);
    }
  }

  Future<void> _saveCalendar() async {
    setState(() => _isSaving = true);
    try {
      final List<Map<String, dynamic>> calendarData = [];
      for (int i = 0; i < _days.length; i++) {
        calendarData.add({
          'day': _days[i].day,
          'date': _days[i].date.toIso8601String(),
          'sehri': _sehriControllers[i].text.trim(),
          'iftar': _iftarControllers[i].text.trim(),
        });
      }

      await FirebaseFirestore.instance.collection('settings').doc('ramzan_calendar').set({
        'year': DateTime.now().year,
        'schedule': calendarData,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Color(0xFF10B981), content: Text("Ramzan Calendar updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Failed to save: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmall ? 16 : 24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCalendarTable(isSmall),
                          const SizedBox(height: 40),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _clearAll() {
    for (var c in _sehriControllers) {
      c.clear();
    }
    for (var c in _iftarControllers) {
      c.clear();
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      final service = NotificationApiService();
      final result = await service.testRamzanNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF6366F1),
            content: Text("Test sent: ${result['phraseAtRuntime']}"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Test failed: $e")),
        );
      }
    }
  }

  Widget _buildCalendarTable(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CONSOLIDATED TIMINGS",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.1),
                  ),
                  Text("Manage Sehri & Iftar schedules", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _sendTestNotification,
                    icon: const Icon(Icons.notification_important_rounded, size: 18, color: Color(0xFF6366F1)),
                    label: const Text("TEST ALERT", style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                    label: const Text("CLEAR ALL", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _days.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade50),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 48,
                          height: 36,
                          decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Center(
                            child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6366F1))),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(DateFormat('MMM dd').format(_days[index].date), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTimeInput("Sehri", _sehriControllers[index], true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimeInput("Iftar", _iftarControllers[index], false),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _testDay(index + 1),
                            icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF6366F1)),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1).withOpacity(0.08),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _testDay(int day) async {
    try {
      final service = NotificationApiService();
      await service.testDayRozaNotification(day);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF6366F1),
            content: Text("Day $day Test Sent: 5m Alert & Dua"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Failed: $e")),
        );
      }
    }
  }

  Widget _buildTimeInput(String label, TextEditingController controller, bool isSehri) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectTime(context, controller, isSehri),
          child: IgnorePointer(
            child: SizedBox(
              height: 40,
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "--:-- --",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                  fillColor: const Color(0xFFF8FAFC),
                  filled: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveCalendar,
        icon: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
        label: Text(_isSaving ? "SAVING..." : "PUBLISH RAMZAN CALENDAR", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
