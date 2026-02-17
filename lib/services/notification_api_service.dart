import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationApiService {
  // Hosted Render server for production
  static const String baseUrl = 'https://masjid-server-6461.onrender.com/api/notifications';
  
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

    if (topic != null) {
      url = Uri.parse('$baseUrl/send/topic');
      payload['topic'] = topic;
    } else if (target == 'masjid_followers' || target == 'masjid' || target == 'masjid_follower') {
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
      if (kDebugMode) {
        print('Sending notification to: $url');
        print('Payload: ${jsonEncode(payload)}');
      }
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

  Future<Map<String, dynamic>> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    return sendNotification(
      title: title,
      body: body,
      target: 'topic',
      topic: topic,
      data: data,
    );
  }

  Future<Map<String, dynamic>> testRamzanNotification() async {
    final url = Uri.parse('$baseUrl/test-ramzan');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'X-Admin-API-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send test notification: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  Future<Map<String, dynamic>> testDayRozaNotification(int day) async {
    final url = Uri.parse('$baseUrl/test-roza');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'X-Admin-API-Key': apiKey,
        },
        body: jsonEncode({'day': day}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send roza test: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }
}
