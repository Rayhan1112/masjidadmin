import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarDay {
  final int day;
  String sehri;
  String iftar;

  CalendarDay({required this.day, this.sehri = "", this.iftar = ""});

  Map<String, dynamic> toMap() => {
    'day': day,
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
  final List<CalendarDay> _days = List.generate(30, (i) => CalendarDay(day: i + 1));
  late List<TextEditingController> _sehriControllers;
  late List<TextEditingController> _iftarControllers;
  
  XFile? _image;
  bool _isProcessing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sehriControllers = List.generate(30, (i) => TextEditingController());
    _iftarControllers = List.generate(30, (i) => TextEditingController());
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

  Future<void> _pickAndProcessImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _image = image;
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      final extractedData = _parseRecognizedText(recognizedText);
      textRecognizer.close();

      if (extractedData.isNotEmpty) {
        _showReviewDialog(extractedData);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No timings could be detected. Try a clearer image.")),
          );
        }
      }
    } catch (e) {
      debugPrint("OCR Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing image: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _clearAll() {
    for (var c in _sehriControllers) {
      c.clear();
    }
    for (var c in _iftarControllers) {
      c.clear();
    }
  }

  List<Map<String, String>> _parseRecognizedText(RecognizedText recognizedText) {
    List<TextBlock> blocks = recognizedText.blocks;
    if (blocks.isEmpty) return [];

    final timeRegex = RegExp(r'(\d{1,2})[:. ](\d{2})');
    final dayRegex = RegExp(r'(\d{1,2})');

    List<Map<String, dynamic>> items = [];

    for (var block in blocks) {
      for (var line in block.lines) {
        final text = line.text.trim();
        final rect = line.boundingBox;

        final timeMatch = timeRegex.firstMatch(text);
        if (timeMatch != null) {
          String hour = timeMatch.group(1)!;
          String min = timeMatch.group(2)!;
          items.add({
            'type': 'time', 
            'value': "${hour.padLeft(2, '0')}:$min", 
            'y': rect.top, 
            'x': rect.left
          });
        } else {
          final dayMatch = dayRegex.firstMatch(text);
          if (dayMatch != null) {
            int? val = int.tryParse(dayMatch.group(1)!);
            if (val != null && val >= 1 && val <= 30) {
              items.add({
                'type': 'day', 
                'value': val, 
                'y': rect.top, 
                'x': rect.left
              });
            }
          }
        }
      }
    }

    if (items.isEmpty) return [];

    items.sort((a, b) => a['y'].compareTo(b['y']));

    double rowThreshold = 30.0;
    List<List<Map<String, dynamic>>> rows = [];
    
    List<Map<String, dynamic>> currentRow = [items[0]];
    for (int i = 1; i < items.length; i++) {
      if ((items[i]['y'] - currentRow[0]['y']).abs() < rowThreshold) {
        currentRow.add(items[i]);
      } else {
        rows.add(currentRow);
        currentRow = [items[i]];
      }
    }
    rows.add(currentRow);

    List<Map<String, String>> results = [];
    for (var row in rows) {
      row.sort((a, b) => a['x'].compareTo(b['x']));
      
      int? foundDay;
      List<String> foundTimes = [];

      for (var item in row) {
        if (item['type'] == 'day' && foundDay == null) {
          foundDay = item['value'];
        } else if (item['type'] == 'time') {
          foundTimes.add(item['value']);
        }
      }

      if (foundDay != null && foundDay >= 1 && foundDay <= 30 && foundTimes.isNotEmpty) {
        results.add({
          'day': foundDay.toString(),
          'sehri': foundTimes[0],
          'iftar': foundTimes.length > 1 ? foundTimes.last : "",
        });
      }
    }
    return results;
  }

  void _showReviewDialog(List<Map<String, String>> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.fact_check_rounded, color: Color(0xFF6366F1), size: 32),
                ),
                const SizedBox(height: 16),
                const Text("Review Extracted Data", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const Text("We detected the following timings from the card:", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: data.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final item = data[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Text("DAY ${item['day']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF6366F1))),
                                const Spacer(),
                                _buildBadge("Sehri: ${item['sehri']}", const Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                _buildBadge("Iftar: ${item['iftar']}", const Color(0xFFF59E0B)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("CANCEL", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          for (var item in data) {
                            int d = int.parse(item['day']!);
                            _sehriControllers[d - 1].text = item['sehri']!;
                            _iftarControllers[d - 1].text = item['iftar']!;
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: const Color(0xFF10B981), content: Text("Added ${data.length} days successfully!")),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text("ADD TO TABLE", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Future<void> _saveCalendar() async {
    setState(() => _isSaving = true);
    try {
      final List<Map<String, dynamic>> calendarData = [];
      for (int i = 0; i < 30; i++) {
        calendarData.add({
          'day': i + 1,
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
                          _buildPickerSection(isSmall),
                          const SizedBox(height: 32),
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

  Widget _buildPickerSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "STEP 1: UPLOAD CALENDAR IMAGE",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.1),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _isProcessing ? null : _pickAndProcessImage,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              image: _image != null ? DecorationImage(image: FileImage(File(_image!.path)), fit: BoxFit.contain, opacity: 0.3) : null,
            ),
            child: Center(
              child: _isProcessing
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF6366F1)),
                        SizedBox(height: 16),
                        Text("Extracting timings...", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF6366F1), size: 32),
                        ),
                        const SizedBox(height: 12),
                        const Text("Select Calendar Photo", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const Text("We will automatically read the timings", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
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
                   "STEP 2: VERIFY TIMINGS",
                   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.1),
                 ),
                 Text("Verify all 30 days", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
               ],
             ),
             TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
              label: const Text("CLEAR ALL", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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
            itemCount: 30,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade50),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTimeInput("Sehri", _sehriControllers[index]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimeInput("Iftar", _iftarControllers[index]),
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

  Widget _buildTimeInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1))),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
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
