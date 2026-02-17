import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:masjidadmin/screens/masjid_admin/admin_home_screen.dart';
import 'package:masjidadmin/screens/auth/login_screen.dart';
import 'package:masjidadmin/screens/super_admin/super_admin_screen.dart';
import 'package:masjidadmin/services/fcm_service.dart';
import 'package:masjidadmin/constants.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  Future<void> _initFCM() async {
    await FCMService.initialize();
  }

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
          
          // Always store token on login/state change
          FCMService.storeTokenToServer(user.uid);

          // Check if this is the super admin
          if (user.email == kSuperAdminEmail) {
            // Ensure Super Admin document exists in 'users' collection
            FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'email': user.email,
              'type': 'super_admin',
              'isAdmin': true,
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            // Subscribe super admin to alerts topic
            debugPrint('[AuthWrapper] Subscribing Super Admin to alerts topic...');
            FCMService.subscribeToSuperAdminAlerts();
            return const SuperAdminScreen();
          } else {
            // Unsubscribe if not super admin (just in case)
            FCMService.unsubscribeFromSuperAdminAlerts();
          }
          return const AdminHomeScreen();
        }

        // If logged out, ensure unsubscribed
        FCMService.unsubscribeFromSuperAdminAlerts();
        
        // Otherwise, the user is not logged in
        return const LoginScreen();
      },
    );
  }
}
