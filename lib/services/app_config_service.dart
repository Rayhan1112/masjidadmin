import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TabConfig {
  final String id;
  final String label;
  final String icon;
  final bool isVisible;
  final int order;

  TabConfig({
    required this.id,
    required this.label,
    required this.icon,
    this.isVisible = true,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'icon': icon,
      'isVisible': isVisible,
      'order': order,
    };
  }

  static TabConfig fromMap(Map<String, dynamic> map) {
    return TabConfig(
      id: map['id'],
      label: map['label'],
      icon: map['icon'] ?? 'circle',
      isVisible: map['isVisible'] ?? true,
      order: map['order'] ?? 0,
    );
  }
}

class AppConfigService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _configDocPath = 'settings/app_navigation';

  static Stream<List<TabConfig>> getTabConfigStream() {
    return _db.doc(_configDocPath).snapshots().map((snapshot) {
      final defaultTabs = _getDefaultTabs();
      
      if (!snapshot.exists || snapshot.data() == null) {
        return defaultTabs;
      }
      
      final List<dynamic> tabsData = snapshot.data()!['tabs'] ?? [];
      final savedTabs = tabsData.map((t) => TabConfig.fromMap(t as Map<String, dynamic>)).toList();
      
      // Merge: Use saved values for existing IDs, use default values for new IDs
      final List<TabConfig> mergedTabs = [];
      
      for (var defTab in defaultTabs) {
        // Find saved tab by current ID or old notifications ID
        final savedTab = savedTabs.where((t) {
          if (defTab.id == 'alerts') return t.id == 'alerts' || t.id == 'notifications';
          return t.id == defTab.id;
        }).firstOrNull;

        if (savedTab != null) {
          // Upgrade icon if needed
          final iconToUse = (savedTab.icon == 'circle' || savedTab.icon.isEmpty) 
              ? defTab.icon 
              : savedTab.icon;
          
          // Upgrade label if it was 'Settings' or 'Notifications'
          String labelToUse = savedTab.label;
          if (savedTab.id == 'profile' && savedTab.label == 'Settings') {
            labelToUse = 'Profile';
          } else if ((savedTab.id == 'notifications' || savedTab.id == 'alerts')) {
            // Force label to be 'Alerts' if it was 'Notifications' or old 'Alerts'
            if (savedTab.label == 'Notifications' || savedTab.label == 'Notifications ') {
              labelToUse = 'Alerts';
            }
          }
          
          mergedTabs.add(TabConfig(
            id: defTab.id, // Migrate 'notifications' to 'alerts'
            label: labelToUse,
            icon: iconToUse,
            isVisible: savedTab.isVisible,
            order: savedTab.order,
          ));
        } else {
          mergedTabs.add(defTab);
        }
      }
      
      mergedTabs.sort((a, b) => a.order.compareTo(b.order));
      return mergedTabs;
    });
  }

  static Future<void> saveTabConfig(List<TabConfig> tabs) async {
    final tabsData = tabs.map((t) => t.toMap()).toList();
    // Using update instead of set with merge to be absolutely sure we only touch 'tabs'
    await _db.doc(_configDocPath).update({'tabs': tabsData});
  }

  static List<TabConfig> _getDefaultTabs() {
    return [
      TabConfig(id: 'home', label: 'Home', icon: 'home', order: 0),
      TabConfig(id: 'masjids', label: 'Masjids', icon: 'mosque', order: 1),
      TabConfig(id: 'jumma', label: 'Jumma', icon: 'calendar', order: 2),
      TabConfig(id: 'sehri', label: 'Sehri', icon: 'restaurant', order: 3),
      TabConfig(id: 'alerts', label: 'Alerts', icon: 'notifications', order: 4, isVisible: true),
      TabConfig(id: 'profile', label: 'Profile', icon: 'person', order: 5),
    ];
  }
}
