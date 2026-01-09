import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/event_summary.dart';
import 'api_exceptions.dart';

class EventsService {
  EventsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<EventSummary>> fetchEvents(String token) async {
    final baseUrl = _normalizeBaseUrl(dotenv.env['EVENTS_API_BASE_URL'] ?? '');
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

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
