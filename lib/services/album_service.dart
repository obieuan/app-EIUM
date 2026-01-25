import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;

import '../models/album_entry.dart';
import '../models/public_card_data.dart';
import 'api_exceptions.dart';

class AlbumService {
  AlbumService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetch a preview of another user's card by matricula.
  Future<PublicCardData?> fetchPreview(String token, String matricula) async {
    final baseUrl = _normalizeBaseUrl(
      AppConfig.eventsApiBaseUrl.isNotEmpty
          ? AppConfig.eventsApiBaseUrl
          : AppConfig.apiBaseUrl,
    );
    if (baseUrl.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$baseUrl/api/mobile/album/preview/$matricula');
    if (kDebugMode) {
      debugPrint('AlbumService: GET $uri');
    }

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      return null;
    }

    final payload = json.decode(response.body);
    if (payload is Map<String, dynamic>) {
      return PublicCardData.fromJson(payload);
    }
    return null;
  }

  /// Fetch all album entries for the current user.
  Future<List<AlbumEntry>> fetchAlbum(String token) async {
    final baseUrl = _normalizeBaseUrl(
      AppConfig.eventsApiBaseUrl.isNotEmpty
          ? AppConfig.eventsApiBaseUrl
          : AppConfig.apiBaseUrl,
    );
    if (baseUrl.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$baseUrl/api/mobile/album');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode != 200) {
      return [];
    }

    final payload = json.decode(response.body);
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map(AlbumEntry.fromJson)
          .toList();
    }
    return [];
  }

  /// Save an album entry with optional snapshot image.
  Future<AlbumEntry?> saveEntry(
    String token,
    String matricula,
    Uint8List? snapshotBytes,
  ) async {
    final baseUrl = _normalizeBaseUrl(
      AppConfig.eventsApiBaseUrl.isNotEmpty
          ? AppConfig.eventsApiBaseUrl
          : AppConfig.apiBaseUrl,
    );
    if (baseUrl.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$baseUrl/api/mobile/album');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['matricula'] = matricula;

    if (snapshotBytes != null && snapshotBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'snapshot',
          snapshotBytes,
          filename: 'snapshot_${DateTime.now().millisecondsSinceEpoch}.png',
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
      return AlbumEntry.fromJson(payload);
    }
    return null;
  }

  /// Scan a card and update/create the album entry, optionally completing MUTUAL_SCAN.
  Future<Map<String, dynamic>?> scanCard(
    String token,
    String matricula,
    Uint8List? snapshotBytes,
  ) async {
    if (kDebugMode) {
      debugPrint('AlbumService: scanCard called');
      debugPrint('  - matricula: $matricula');
      debugPrint('  - snapshotBytes: ${snapshotBytes != null ? "${snapshotBytes.length} bytes" : "NULL"}');
    }

    final baseUrl = _normalizeBaseUrl(
      AppConfig.eventsApiBaseUrl.isNotEmpty
          ? AppConfig.eventsApiBaseUrl
          : AppConfig.apiBaseUrl,
    );
    if (baseUrl.isEmpty) {
      if (kDebugMode) {
        debugPrint('AlbumService: baseUrl is empty!');
      }
      return null;
    }

    final uri = Uri.parse('$baseUrl/api/mobile/album/scan');
    if (kDebugMode) {
      debugPrint('AlbumService: POST $uri');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['matricula'] = matricula;

    if (snapshotBytes != null && snapshotBytes.isNotEmpty) {
      final filename = 'snapshot_${DateTime.now().millisecondsSinceEpoch}.png';
      request.files.add(
        http.MultipartFile.fromBytes(
          'snapshot',
          snapshotBytes,
          filename: filename,
        ),
      );
      if (kDebugMode) {
        debugPrint('AlbumService: Added snapshot file: $filename (${snapshotBytes.length} bytes)');
      }
    } else {
      if (kDebugMode) {
        debugPrint('AlbumService: NO snapshot file added to request');
      }
    }

    final streamed = await _client.send(request);
    if (kDebugMode) {
      debugPrint('AlbumService: Response status: ${streamed.statusCode}');
    }

    if (streamed.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (streamed.statusCode != 200) {
      if (kDebugMode) {
        final errorBody = await streamed.stream.bytesToString();
        debugPrint('AlbumService: Error response: $errorBody');
      }
      return null;
    }

    final body = await streamed.stream.bytesToString();
    if (kDebugMode) {
      debugPrint('AlbumService: Response body: $body');
    }

    final payload = _tryDecodeJson(body);
    if (payload is Map<String, dynamic>) {
      return payload;
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
