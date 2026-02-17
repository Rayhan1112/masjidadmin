import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:masjidadmin/services/notification_api_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }
    }

    // Initialize Local Notifications for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(initializationSettings);

    // Create High Priority Channel for Android
    if (!kIsWeb) {
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_priority', // ID same as server
        'High Priority Alerts', // Name
        description: 'Used for important tiffin orders and urgent alerts.',
        importance: Importance.max,
        vibrationPattern: Int64List.fromList([0, 1000]),
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Subscribe to all_users topic for general alerts
    await subscribeToAllUsers();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print('Foreground message received');
      }

      // Strong haptic vibration for EVERY foreground message
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 1000);
      }

      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Handle token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      // Token update logic handled in AuthWrapper
    });
  }

  static void _showLocalNotification(RemoteMessage message) {
    _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_priority',
          'High Priority Alerts',
          importance: Importance.max,
          priority: Priority.max,
          ticker: 'ticker',
          vibrationPattern: kIsWeb ? null : Int64List.fromList([0, 1000]),
          enableVibration: true,
          fullScreenIntent: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> subscribeToAllUsers() async {
    if (kIsWeb) {
      if (kDebugMode) {
        print('Topic subscriptions not supported on web - skipping all_users subscription');
      }
      return;
    }
    
    try {
      await _messaging.subscribeToTopic('all_users');
      if (kDebugMode) {
        print('Subscribed to all_users');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to all_users: $e');
      }
    }
  }

  static Future<void> storeTokenToServer(String userId) async {
    try {
      String? token = await _messaging.getToken();
      
      if (token == null) return;

      if (kDebugMode) {
        print('Storing FCM Token for $userId: $token');
      }

      final url = Uri.parse('${NotificationApiService.baseUrl}/tokens/store');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'token': token,
          'deviceInfo': {
            'platform': defaultTargetPlatform.toString(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Token successfully stored on server');
        }
      } else {
        if (kDebugMode) {
          print('Failed to store token: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error storing token: $e');
      }
    }
  }

  static Future<void> subscribeToSuperAdminAlerts() async {
    if (kIsWeb) {
      if (kDebugMode) {
        print('Topic subscriptions not supported on web - skipping super_admin_alerts subscription');
      }
      return;
    }
    
    try {
      await _messaging.subscribeToTopic('super_admin_alerts');
      debugPrint('[FCMService] successfully subscribed to topic: super_admin_alerts');
    } catch (e) {
      debugPrint('[FCMService] Error subscribing to super_admin_alerts: $e');
    }
  }

  static Future<void> unsubscribeFromSuperAdminAlerts() async {
    if (kIsWeb) {
      if (kDebugMode) {
        print('Topic subscriptions not supported on web - skipping super_admin_alerts unsubscription');
      }
      return;
    }
    
    try {
      await _messaging.unsubscribeFromTopic('super_admin_alerts');
      if (kDebugMode) {
        print('Unsubscribed from super_admin_alerts');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from super_admin_alerts: $e');
      }
    }
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}
