import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/checkin_result.dart';
import '../models/challenge_summary.dart';
import '../models/weekly_challenge.dart';
import 'api_exceptions.dart';

enum MutualScanStatus { completed, alreadyCompleted, noChallenge }

class MutualScanResult {
  final MutualScanStatus status;
  final int hurraEarned;

  const MutualScanResult._(this.status, this.hurraEarned);

  factory MutualScanResult.completed(int hurra) =>
      MutualScanResult._(MutualScanStatus.completed, hurra);

  factory MutualScanResult.alreadyCompleted() =>
      const MutualScanResult._(MutualScanStatus.alreadyCompleted, 0);

  factory MutualScanResult.noChallenge() =>
      const MutualScanResult._(MutualScanStatus.noChallenge, 0);

  bool get isCompleted => status == MutualScanStatus.completed;
  bool get isAlreadyCompleted => status == MutualScanStatus.alreadyCompleted;
  bool get hasNoChallenge => status == MutualScanStatus.noChallenge;
}

class ChallengeService {
  ChallengeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ChallengeSummary> fetchSummary(String token) async {
    final baseUrl = _normalizeBaseUrl(dotenv.env['EVENTS_API_BASE_URL'] ?? '');
    if (baseUrl.isEmpty) {
      return ChallengeSummary.empty();
    }

    final uri = Uri.parse('$baseUrl/api/mobile/challenges/summary');
    if (kDebugMode) {
      debugPrint('API DEBUG challenges -> $uri');
    }
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (kDebugMode) {
      debugPrint('API DEBUG challenges status=${response.statusCode}');
    }

    if (response.statusCode == 403) {
      return ChallengeSummary.empty(permissionDenied: true);
    }
    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode != 200) {
      throw StateError('Challenges request failed (${response.statusCode}).');
    }

    final payload = json.decode(response.body);
    if (payload is! Map<String, dynamic>) {
      return ChallengeSummary.empty();
    }

    if (payload.containsKey('hurra_total') ||
        payload.containsKey('antorcha_total')) {
      final hurraTotal = _parseInt(payload['hurra_total']);
      final antorchaTotal = _parseInt(payload['antorcha_total']);
      final weeklyRequirement = _parseInt(payload['weekly_required']);
      return ChallengeSummary(
        hurraTotal: hurraTotal,
        antorchaTotal: antorchaTotal,
        weeklyRequirement: weeklyRequirement > 0 ? weeklyRequirement : 1,
        permissionDenied: false,
      );
    }

    final history = payload['history'];
    final weeklyRequirement = _resolveWeeklyRequirement(payload);

    if (history is! List) {
      return ChallengeSummary.empty();
    }

    var hurraTotal = 0;
    final weeklyCounts = <int, int>{};

    for (final item in history) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final template = item['template'];
      if (template is! Map<String, dynamic>) {
        continue;
      }

      final givesHurra = _parseBool(template['gives_hurra']);
      final givesHurraExtra = _parseBool(template['gives_hurra_extra']);
      if (givesHurra) {
        hurraTotal += _parseInt(template['hurra_reward']);
      }
      if (givesHurraExtra) {
        hurraTotal += _parseInt(template['hurra_extra_value']);
      }

      if (_parseBool(template['counts_for_weekly_participation'])) {
        var weekId = _parseInt(item['week_config_id']);
        if (weekId <= 0) {
          final week = item['week'];
          if (week is Map<String, dynamic>) {
            weekId = _parseInt(week['id']);
          }
        }
        if (weekId > 0) {
          weeklyCounts[weekId] = (weeklyCounts[weekId] ?? 0) + 1;
        }
      }
    }

    final antorchas = weeklyCounts.values
        .where((count) => count >= weeklyRequirement)
        .length;

    return ChallengeSummary(
      hurraTotal: hurraTotal,
      antorchaTotal: antorchas,
      weeklyRequirement: weeklyRequirement,
      permissionDenied: false,
    );
  }

  Future<List<WeeklyChallenge>> fetchWeeklyChallenges(String token) async {
    final baseUrl = _normalizeBaseUrl(dotenv.env['EVENTS_API_BASE_URL'] ?? '');
    if (baseUrl.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$baseUrl/api/mobile/challenges/week');
    if (kDebugMode) {
      debugPrint('API DEBUG weekly challenges -> $uri');
    }
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (kDebugMode) {
      debugPrint('API DEBUG weekly challenges status=${response.statusCode}');
    }

    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode != 200) {
      return [];
    }

    final payload = json.decode(response.body);
    if (payload is! Map<String, dynamic>) {
      return [];
    }

    final assigned = payload['assigned'];
    if (assigned is! List) {
      return [];
    }

    return assigned
        .whereType<Map<String, dynamic>>()
        .map(WeeklyChallenge.fromJson)
        .toList();
  }

  /// Attempts to complete a MUTUAL_SCAN challenge when scanning another user's QR.
  /// Returns a result indicating success, already completed, or no matching challenge.
  Future<MutualScanResult> tryCompleteMutualScan(String token, String peerMatricula) async {
    final baseUrl = _normalizeBaseUrl(dotenv.env['EVENTS_API_BASE_URL'] ?? '');
    if (baseUrl.isEmpty) {
      return MutualScanResult.noChallenge();
    }

    final uri = Uri.parse('$baseUrl/api/challenges/complete');
    final payload = {
      'code': 'MUTUAL_SCAN',
      'source_type': 'MUTUAL_SCAN',
      'source_id': peerMatricula,
      'metadata': {'peer_matricula': peerMatricula},
    };

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 401) {
        throw const TokenExpiredException();
      }

      if (response.statusCode == 422) {
        // No active challenge or validation failed
        return MutualScanResult.noChallenge();
      }

      if (response.statusCode != 200) {
        return MutualScanResult.noChallenge();
      }

      final body = json.decode(response.body);
      if (body is Map<String, dynamic>) {
        final status = body['status']?.toString() ?? '';
        if (status == 'completed') {
          return MutualScanResult.completed(body['hurra_earned'] as int? ?? 0);
        }
        if (status == 'already_completed') {
          return MutualScanResult.alreadyCompleted();
        }
      }
      return MutualScanResult.noChallenge();
    } catch (e) {
      if (e is TokenExpiredException) rethrow;
      return MutualScanResult.noChallenge();
    }
  }

  Future<CheckinResult> checkin(String token, {DateTime? date}) async {
    final baseUrl = _normalizeBaseUrl(dotenv.env['EVENTS_API_BASE_URL'] ?? '');
    if (baseUrl.isEmpty) {
      return CheckinResult.error('No hay configuracion de eventos.');
    }

    final uri = Uri.parse('$baseUrl/api/mobile/challenges/checkin');
    final payload = <String, dynamic>{};
    if (date != null) {
      payload['checkin_date'] = _formatDate(date);
    }

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }

    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    }

    if (response.statusCode != 200) {
      final message =
          (body['message'] as String?) ?? 'No se pudo registrar el check-in.';
      return CheckinResult.error(message);
    }

    return CheckinResult.fromJson(body);
  }

  int _resolveWeeklyRequirement(Map<String, dynamic> payload) {
    final week = payload['week'];
    if (week is Map<String, dynamic>) {
      final season = week['season'];
      if (season is Map<String, dynamic>) {
        final autopilot = season['autopilot_config'];
        if (autopilot is Map<String, dynamic>) {
          final value = _parseInt(autopilot['active_challenges_required']);
          if (value > 0) {
            return value;
          }
        }
      }
    }
    return 1;
  }

  bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
