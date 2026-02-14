import 'package:flutter/material.dart';
import 'package:masjidadmin/screens/super_admin/super_admin_dashboard_screen.dart';
import 'package:masjidadmin/screens/common/notification_sender_screen.dart';
import 'package:masjidadmin/screens/common/in_app_message_screen.dart';
import 'package:masjidadmin/screens/common/profile_screen.dart';
import 'package:masjidadmin/widgets/super_admin_layout.dart';
import 'package:masjidadmin/screens/super_admin/all_masjids_screen.dart';
import 'package:masjidadmin/screens/super_admin/all_admins_screen.dart';

import 'package:masjidadmin/screens/super_admin/ads_management_screen.dart';
import 'package:masjidadmin/screens/super_admin/ramzan_calendar_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    SuperAdminDashboardScreen(),
    AllMasjidsScreen(),
    AllAdminsScreen(),
    NotificationSenderScreen(),
    InAppMessageScreen(),
    AdsManagementScreen(),
    RamzanCalendarScreen(),
  ];

  static const List<String> _titles = <String>[
    'Dashboard',
    'All Masjids',
    'All Admins',
    'Notifications',
    'In-App Messages',
    'Ads Management',
    'Ramzan Calendar',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SuperAdminLayout(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      title: _titles[_selectedIndex],
      child: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
    );
  }
}
