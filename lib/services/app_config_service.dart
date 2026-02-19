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

class ToolConfig {
  final String id;
  final String label;
  final bool isEnabled;

  ToolConfig({
    required this.id,
    required this.label,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'isEnabled': isEnabled,
    };
  }

  static ToolConfig fromMap(Map<String, dynamic> map) {
    return ToolConfig(
      id: map['id'],
      label: map['label'],
      isEnabled: map['isEnabled'] ?? true,
    );
  }
}

class KidsFeatureConfig {
  final String id;
  final String label;
  final bool isEnabled;

  KidsFeatureConfig({
    required this.id,
    required this.label,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'isEnabled': isEnabled,
    };
  }

  static KidsFeatureConfig fromMap(Map<String, dynamic> map) {
    return KidsFeatureConfig(
      id: map['id'],
      label: map['label'],
      isEnabled: map['isEnabled'] ?? true,
    );
  }
}

class AppConfigService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _configDocPath = 'settings/app_navigation';
  static const String _toolsDocPath = 'settings/app_tools';
  static const String _kidsDocPath = 'settings/kids_settings';

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

  static Stream<List<ToolConfig>> getToolConfigStream() {
    return _db.doc(_toolsDocPath).snapshots().map((snapshot) {
      final defaultTools = _getDefaultTools();
      if (!snapshot.exists || snapshot.data() == null) {
        return defaultTools;
      }
      final List<dynamic> toolsData = snapshot.data()!['tools'] ?? [];
      final savedTools = toolsData.map((t) => ToolConfig.fromMap(t as Map<String, dynamic>)).toList();

      final List<ToolConfig> mergedTools = [];
      for (var defTool in defaultTools) {
        final savedTool = savedTools.where((t) => t.id == defTool.id).firstOrNull;
        if (savedTool != null) {
          mergedTools.add(ToolConfig(
            id: defTool.id,
            label: defTool.label,
            isEnabled: savedTool.isEnabled,
          ));
        } else {
          mergedTools.add(defTool);
        }
      }
      return mergedTools;
    });
  }

  static Future<void> saveToolConfig(List<ToolConfig> tools) async {
    final toolsData = tools.map((t) => t.toMap()).toList();
    await _db.doc(_toolsDocPath).set({'tools': toolsData}, SetOptions(merge: true));
  }

  static Stream<List<KidsFeatureConfig>> getKidsConfigStream() {
    return _db.doc(_kidsDocPath).snapshots().map((snapshot) {
      final defaultFeatures = _getDefaultKidsFeatures();
      if (!snapshot.exists || snapshot.data() == null) {
        return defaultFeatures;
      }
      final List<dynamic> data = snapshot.data()!['features'] ?? [];
      final savedFeatures = data.map((t) => KidsFeatureConfig.fromMap(t as Map<String, dynamic>)).toList();

      final List<KidsFeatureConfig> merged = [];
      for (var def in defaultFeatures) {
        final saved = savedFeatures.where((t) => t.id == def.id).firstOrNull;
        if (saved != null) {
          merged.add(KidsFeatureConfig(
            id: def.id,
            label: def.label,
            isEnabled: saved.isEnabled,
          ));
        } else {
          merged.add(def);
        }
      }
      return merged;
    });
  }

  static Future<void> saveKidsConfig(List<KidsFeatureConfig> features) async {
    final data = features.map((t) => t.toMap()).toList();
    await _db.doc(_kidsDocPath).set({'features': data}, SetOptions(merge: true));
  }

  static List<TabConfig> _getDefaultTabs() {
    return [
      TabConfig(id: 'home', label: 'Home', icon: 'home', order: 0),
      TabConfig(id: 'masjids', label: 'Masjids', icon: 'mosque', order: 1),
      TabConfig(id: 'jumma', label: 'Jumma', icon: 'calendar', order: 2),
      TabConfig(id: 'sehri', label: 'Sehri', icon: 'restaurant', order: 3),
      TabConfig(id: 'alerts', label: 'Alerts', icon: 'notifications', order: 4),
      TabConfig(id: 'messages', label: 'Billboard', icon: 'billboard', order: 5),
      TabConfig(id: 'profile', label: 'Profile', icon: 'person', order: 6),
    ];
  }

  static List<ToolConfig> _getDefaultTools() {
    return [
      ToolConfig(id: 'kaza_namaz', label: 'Kaza Namaz Calculator'),
      ToolConfig(id: 'tasbeeh', label: 'Tasbeeh'),
      ToolConfig(id: 'qibla', label: 'Qibla Direction'),
      ToolConfig(id: 'kids', label: 'Kids'),
      ToolConfig(id: 'roza_timing', label: 'Roza Timing Card'),
    ];
  }

  static List<KidsFeatureConfig> _getDefaultKidsFeatures() {
    return [
      KidsFeatureConfig(id: 'kids_dua', label: 'Kids Dua'),
      KidsFeatureConfig(id: 'kids_quiz', label: 'Kids Quiz'),
      KidsFeatureConfig(id: 'kids_stories', label: 'Kids Stories'),
      KidsFeatureConfig(id: 'arabic_lessons', label: 'Arabic Lessons'),
    ];
  }
}

