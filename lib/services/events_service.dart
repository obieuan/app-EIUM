import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;

import '../models/activity_summary.dart';
import '../models/event_summary.dart';
import 'api_exceptions.dart';

class EventsService {
  EventsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<EventSummary>> fetchEvents(String token) async {
    final baseUrl = _normalizeBaseUrl(AppConfig.eventsApiBaseUrl);
    if (baseUrl.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$baseUrl/api/mobile/events');
    if (kDebugMode) {
      debugPrint('API DEBUG events -> $uri');
    }
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (kDebugMode) {
      debugPrint('API DEBUG events status=${response.statusCode}');
    }

    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode != 200) {
      throw StateError('Events request failed (${response.statusCode}).');
    }

    final payload = json.decode(response.body);
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map(EventSummary.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<ActivitySummary>> fetchActivities(String token) async {
    final baseUrl = _normalizeBaseUrl(AppConfig.eventsApiBaseUrl);
    if (baseUrl.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$baseUrl/api/mobile/activities');
    if (kDebugMode) {
      debugPrint('API DEBUG activities -> $uri');
    }
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (kDebugMode) {
      debugPrint('API DEBUG activities status=${response.statusCode}');
    }

    if (response.statusCode == 404) {
      if (kDebugMode) {
        debugPrint('API DEBUG activities 404 (not deployed yet?) -> returning empty list');
      }
      return [];
    }
    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode != 200) {
      throw StateError('Activities request failed (${response.statusCode}).');
    }

    final payload = json.decode(response.body);
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map(ActivitySummary.fromJson)
          .toList();
    }
    return [];
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
