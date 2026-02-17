import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:masjidadmin/screens/super_admin/super_admin_dashboard_screen.dart';
import 'package:masjidadmin/screens/common/notification_sender_screen.dart';
import 'package:masjidadmin/screens/common/in_app_message_screen.dart';
import 'package:masjidadmin/screens/common/profile_screen.dart';
import 'package:masjidadmin/widgets/super_admin_layout.dart';
import 'package:masjidadmin/screens/super_admin/all_masjids_screen.dart';
import 'package:masjidadmin/screens/super_admin/all_admins_screen.dart';

import 'package:masjidadmin/screens/super_admin/ads_management_screen.dart';
import 'package:masjidadmin/screens/super_admin/ramzan_calendar_screen.dart';
import 'package:masjidadmin/screens/super_admin/tiffin_orders_screen.dart';
import 'package:masjidadmin/screens/super_admin/app_settings_screen.dart';
import 'package:masjidadmin/screens/super_admin/failure_logs_screen.dart';
import 'package:masjidadmin/screens/super_admin/analytics_screen.dart';
import 'package:masjidadmin/screens/super_admin/user_list_screen.dart';
import 'package:masjidadmin/screens/super_admin/approval_queue_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  int _selectedIndex = 0;
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startOrderListener();
  }

  void _startOrderListener() {
    FirebaseFirestore.instance
        .collection('tiffin_orders')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(_appStartTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _showNewOrderAlert(change.doc.data() as Map<String, dynamic>);
        }
      }
    });
  }

  void _showNewOrderAlert(Map<String, dynamic> data) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6366F1), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fastfood, color: Color(0xFF6366F1), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "NEW ORDER RECEIVED!",
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Customer: ${data['name'] ?? 'Guest'}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _onItemTapped(10); // Updated index for Tiffin Orders screen
                },
                child: const Text(
                  "VIEW",
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<String> _titles = <String>[
    'Dashboard',
    'Analytics',
    'Users List',
    'Approvals',
    'All Masjids',
    'All Admins',
    'Notifications',
    'In-App Messages',
    'Ads Management',
    'Ramzan Calendar',
    'Tiffin Orders',
    'App Settings',
    'Failure Logs',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = [
      SuperAdminDashboardScreen(onNavigate: _onItemTapped),
      const AnalyticsScreen(),
      const UserListScreen(),
      const ApprovalQueueScreen(),
      const AllMasjidsScreen(),
      const AllAdminsScreen(),
      const NotificationSenderScreen(),
      const InAppMessageScreen(),
      const AdsManagementScreen(),
      const RamzanCalendarScreen(),
      const TiffinOrdersScreen(),
      const AppSettingsScreen(),
      const FailureLogsScreen(),
    ];

    return SuperAdminLayout(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      title: _titles[_selectedIndex],
      child: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
    );
  }
}
