import 'package:flutter/material.dart';
import 'package:masjidadmin/auth_service.dart';

class SuperAdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  SuperAdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C), // Dark elegant background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  index: 0,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.analytics_rounded,
                  label: 'Analytics',
                  index: 1,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.rule_folder_rounded,
                  label: 'Approvals',
                  index: 2,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.mosque_rounded,
                  label: 'All Masjids',
                  index: 3,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.people_alt_rounded,
                  label: 'All Admins',
                  index: 4,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.notifications_active_rounded,
                  label: 'Notifications',
                  index: 5,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.mark_chat_unread_rounded,
                  label: 'Messages',
                  index: 6,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.campaign_rounded,
                  label: 'Ads Management',
                  index: 7,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Ramzan Calendar',
                  index: 8,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.fastfood_rounded,
                  label: 'Tiffin Orders',
                  index: 9,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.tune_rounded,
                  label: 'App Settings',
                  index: 10,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.build_circle_rounded,
                  label: 'Tool Settings',
                  index: 11,
                  colorScheme: colorScheme,
                ),
                _buildNavItem(
                  icon: Icons.bug_report_rounded,
                  label: 'Failure Logs',
                  index: 12,
                  colorScheme: colorScheme,
                ),

              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Super Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Control Panel',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required ColorScheme colorScheme,
  }) {
    final isSelected = selectedIndex == index;
    final primaryColor = const Color(0xFF4A90E2);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: primaryColor.withOpacity(0.5))
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? primaryColor : Colors.white60,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => onDestinationSelected(index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        hoverColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: OutlinedButton.icon(
        onPressed: () async {
          await _authService.signOut();
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Logout'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}
