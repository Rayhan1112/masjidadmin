import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:masjidadmin/screens/masjid_admin/dashboard_screen.dart';
import 'package:masjidadmin/screens/common/profile_screen.dart';
import 'package:masjidadmin/screens/masjid_admin/namaz_timings_screen.dart';
import 'package:masjidadmin/screens/common/notification_sender_screen.dart';
import 'package:masjidadmin/screens/super_admin/all_masjids_screen.dart';
import 'package:masjidadmin/screens/super_admin/ramzan_calendar_screen.dart';
import 'package:masjidadmin/services/app_config_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  String? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _userRole = doc.data()?['type'];
          _isLoadingRole = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Widget _getScreen(String id) {
    switch (id) {
      case 'home':
        return const DashboardScreen();
      case 'masjids':
        return const AllMasjidsScreen();
      case 'jumma':
        return const NamazTimingsScreen();
      case 'sehri':
        return const RamzanCalendarScreen();
      case 'notifications':
      case 'alerts':
        return const NotificationSenderScreen();
      case 'profile':
        return const ProfileScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<TabConfig>>(
      stream: AppConfigService.getTabConfigStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final allTabs = snapshot.data!;
        List<TabConfig> visibleTabs;

        if (_userRole == 'masjidAdmin') {
          // RESTRICTED VIEW: Only Home (Edit) and Profile
          visibleTabs = allTabs.where((t) => t.id == 'home' || t.id == 'profile').toList();
        } else {
          // NORMAL VIEW for regular users or others
          visibleTabs = allTabs.where((t) => t.isVisible).toList();
        }

        // Ensure current selection is valid
        if (_selectedIndex >= visibleTabs.length) {
          _selectedIndex = 0;
        }

        final List<Widget> screens = visibleTabs.map((t) => _getScreen(t.id)).toList();

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: visibleTabs.map((tab) {
              return BottomNavigationBarItem(
                icon: Icon(_getIconByName(tab.icon, false)),
                activeIcon: Icon(_getIconByName(tab.icon, true)),
                label: tab.label,
              );
            }).toList(),
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }

  IconData _getIconByName(String name, bool active) {
    switch (name) {
      case 'home':
        return active ? Icons.home : Icons.home_outlined;
      case 'mosque':
        return active ? Icons.mosque : Icons.mosque_outlined;
      case 'calendar':
        return active ? Icons.calendar_today : Icons.calendar_today_outlined;
      case 'restaurant':
        return active ? Icons.restaurant : Icons.restaurant_outlined;
      case 'notifications':
        return active ? Icons.notifications : Icons.notifications_none_rounded;
      case 'person':
        return active ? Icons.person : Icons.person_outline;
      default:
        return Icons.circle;
    }
  }
}
