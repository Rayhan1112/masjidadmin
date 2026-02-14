import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:masjidadmin/screens/masjid_admin/admin_home_screen.dart';
import 'package:masjidadmin/screens/auth/login_screen.dart';
import 'package:masjidadmin/screens/super_admin/super_admin_screen.dart';

import 'package:masjidadmin/constants.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If the snapshot has data, it means the user is logged in
        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Check if this is the super admin
          if (user.email == kSuperAdminEmail) {
            return const SuperAdminScreen();
          }
          return const AdminHomeScreen();
        }

        // Otherwise, the user is not logged in
        return const LoginScreen();
      },
    );
  }
}
