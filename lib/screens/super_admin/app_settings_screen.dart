import 'package:flutter/material.dart';
import 'package:masjidadmin/services/app_config_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  List<TabConfig> _tabs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final stream = AppConfigService.getTabConfigStream();
    final first = await stream.first;
    setState(() {
      _tabs = first;
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    try {
      // Update orders before saving
      for (int i = 0; i < _tabs.length; i++) {
        _tabs[i] = _updateOrder(_tabs[i], i);
      }
      await AppConfigService.saveTabConfig(_tabs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Navigation settings saved successfully"),
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

  TabConfig _updateOrder(TabConfig tab, int newOrder) {
    return TabConfig(
      id: tab.id,
      label: tab.label,
      icon: tab.icon,
      isVisible: tab.isVisible,
      order: newOrder,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("App Navigation Settings", 
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
                Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Decide which tabs appear in the app's bottom navigation bar. Drag to reorder or toggle visibility.",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tabs.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                return Card(
                  key: ValueKey(tab.id),
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
                        color: (tab.isVisible ? const Color(0xFF6366F1) : Colors.grey).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getIconByName(tab.icon), color: tab.isVisible ? const Color(0xFF6366F1) : Colors.grey),
                    ),
                    title: Text(
                      tab.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tab.isVisible ? const Color(0xFF1E293B) : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      tab.isVisible ? "Visible to App Admins" : "Hidden in App",
                      style: TextStyle(
                        fontSize: 12,
                        color: tab.isVisible ? const Color(0xFF64748B) : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tab.id == 'sehri' || tab.id == 'notifications' || tab.id == 'alerts')
                          Switch(
                            value: tab.isVisible,
                            activeColor: const Color(0xFF6366F1),
                            onChanged: (val) {
                              setState(() {
                                _tabs[index] = TabConfig(
                                  id: tab.id,
                                  label: tab.label,
                                  icon: tab.icon,
                                  isVisible: val,
                                  order: tab.order,
                                );
                              });
                            },
                          )
                        else
                          const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                      ],
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

  IconData _getIconByName(String name) {
    switch (name) {
      case 'home': return Icons.home_rounded;
      case 'mosque': return Icons.mosque_rounded;
      case 'calendar': return Icons.calendar_today_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'notifications': return Icons.notifications_rounded;
      case 'person': return Icons.person_rounded;
      default: return Icons.circle;
    }
  }
}
