import 'package:flutter/material.dart';
import 'package:masjidadmin/services/app_config_service.dart';

class ToolSettingsScreen extends StatefulWidget {
  const ToolSettingsScreen({super.key});

  @override
  State<ToolSettingsScreen> createState() => _ToolSettingsScreenState();
}

class _ToolSettingsScreenState extends State<ToolSettingsScreen> {
  List<ToolConfig> _tools = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final stream = AppConfigService.getToolConfigStream();
    final first = await stream.first;
    setState(() {
      _tools = first;
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    try {
      await AppConfigService.saveToolConfig(_tools);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tool rendering settings saved successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("App Tools Rendering", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text("SAVE CHANGES"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: const Row(
              children: [
                Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Enable or disable specific features in the Client App. Disabled tools will not be visible to users.",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tools.length,
              itemBuilder: (context, index) {
                final tool = _tools[index];
                return Card(
                  key: ValueKey(tool.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (tool.isEnabled ? const Color(0xFF6366F1) : Colors.grey).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getIconForTool(tool.id), color: tool.isEnabled ? const Color(0xFF6366F1) : Colors.grey),
                    ),
                    title: Text(
                      tool.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tool.isEnabled ? const Color(0xFF1E293B) : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      tool.isEnabled ? "Visible in Client App" : "Hidden in Client App",
                      style: TextStyle(
                        fontSize: 12,
                        color: tool.isEnabled ? const Color(0xFF64748B) : Colors.grey,
                      ),
                    ),
                    trailing: Switch(
                      value: tool.isEnabled,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() {
                          _tools[index] = ToolConfig(
                            id: tool.id,
                            label: tool.label,
                            isEnabled: val,
                          );
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
}
