import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import 'api_exceptions.dart';

class ProfileService {
  ProfileService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UserProfile?> fetchProfile(String token) async {
    final baseUrl = _normalizeBaseUrl(
      AppConfig.eventsApiBaseUrl.isNotEmpty
          ? AppConfig.eventsApiBaseUrl
          : AppConfig.apiBaseUrl,
    );
    if (baseUrl.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$baseUrl/api/mobile/profile');
    if (kDebugMode) {
      debugPrint('API DEBUG profile -> $uri');
    }

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (kDebugMode) {
      debugPrint('API DEBUG profile status=${response.statusCode}');
    }
    if (response.statusCode == 401) {
      final payload = _tryDecodeJson(response.body);
      if (payload is Map<String, dynamic> &&
          payload['error'] == 'token_expired') {
        throw const TokenExpiredException();
      }
      throw StateError('Unauthorized.');
    }
    if (response.statusCode != 200) {
      throw StateError('Profile request failed (${response.statusCode}).');
    }

    final payload = json.decode(response.body);
    if (payload is Map<String, dynamic>) {
      return UserProfile.fromJson(payload);
    }
    return null;
  }

  Future<String?> updatePhoto(String token, XFile file) async {
    final baseUrl = _normalizeBaseUrl(
      AppConfig.eventsApiBaseUrl.isNotEmpty
          ? AppConfig.eventsApiBaseUrl
          : AppConfig.apiBaseUrl,
    );
    if (baseUrl.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$baseUrl/api/mobile/profile/photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'Foto',
          bytes,
          filename: file.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'Foto',
          file.path,
          filename: file.name,
        ),
      );
    }

    final streamed = await _client.send(request);
    if (streamed.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (streamed.statusCode != 200) {
      return null;
    }

    final body = await streamed.stream.bytesToString();
    final payload = _tryDecodeJson(body);
    if (payload is Map<String, dynamic>) {
      return payload['photo_url']?.toString();
    }
    return null;
  }

  dynamic _tryDecodeJson(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
