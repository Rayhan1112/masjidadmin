import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationApiService {
  // Use local server for development
  static String get baseUrl {
    // Use the hosted Render server for all modes as requested
    return 'https://masjid-server.onrender.com/api/notifications';
  }
  
  static const String apiKey = '';

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    required String target,
    String? masjidId,
    String? topic,
    Map<String, dynamic>? data,
  }) async {
    final Uri url;
    final Map<String, dynamic> payload = {
      'title': title,
      'body': body,
      'data': data ?? {},
    };

    if (target == 'masjid_followers' || target == 'masjid') {
      url = Uri.parse('$baseUrl/send/masjid');
      payload['MasjidId'] = masjidId;
    } else if (target == 'all_users') {
      url = Uri.parse('$baseUrl/send/all');
    } else {
       // Default fallback
       url = Uri.parse('$baseUrl/send/masjid');
       payload['MasjidId'] = masjidId; 
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'X-Admin-API-Key': apiKey,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send notification: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }
}
