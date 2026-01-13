import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/card_asset.dart';
import '../models/card_selection.dart';
import 'api_exceptions.dart';

class CardService {
  CardService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<CardAsset>> fetchAssetsBySection(
    String token,
    String section,
  ) async {
    final baseUrl = _normalizeBaseUrl(
      dotenv.env['EVENTS_API_BASE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '',
    );
    if (baseUrl.isEmpty) {
      return [];
    }

    final uri = Uri.parse('$baseUrl/api/vnext/card-assets/sections/$section');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode != 200) {
      return [];
    }

    final payload = json.decode(response.body);
    if (payload is! List) {
      return [];
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(CardAsset.fromJson)
        .map((asset) => _resolveAssetUrl(asset, baseUrl))
        .toList();
  }

  Future<CardSelection?> fetchSelection(String token) async {
    final baseUrl = _normalizeBaseUrl(
      dotenv.env['EVENTS_API_BASE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '',
    );
    if (baseUrl.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$baseUrl/api/vnext/card-selection');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }
    if (response.statusCode != 200) {
      return null;
    }

    final payload = json.decode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final selection = CardSelection.fromJson(payload);
    final resolvedSections = <String, CardAsset?>{};
    selection.sections.forEach((key, asset) {
      resolvedSections[key] =
          asset == null ? null : _resolveAssetUrl(asset, baseUrl);
    });
    final resolvedMedals = <int, CardAsset>{};
    selection.medals.forEach((slot, asset) {
      resolvedMedals[slot] = _resolveAssetUrl(asset, baseUrl);
    });

    return CardSelection(sections: resolvedSections, medals: resolvedMedals);
  }

  Future<bool> updateSelection(
    String token, {
    required String section,
    int? assetId,
    int? slot,
  }) async {
    final baseUrl = _normalizeBaseUrl(
      dotenv.env['EVENTS_API_BASE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '',
    );
    if (baseUrl.isEmpty) {
      return false;
    }

    final uri = Uri.parse('$baseUrl/api/vnext/card-selection');
    final payload = <String, dynamic>{
      'section': section,
      'asset_id': assetId,
      'slot': slot,
    };

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

    return response.statusCode == 200;
  }

  Future<bool> purchaseAsset(String token, int assetId) async {
    final baseUrl = _normalizeBaseUrl(
      dotenv.env['EVENTS_API_BASE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '',
    );
    if (baseUrl.isEmpty) {
      return false;
    }

    final uri = Uri.parse('$baseUrl/api/vnext/card-purchase');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({'asset_id': assetId}),
    );

    if (response.statusCode == 401) {
      throw const TokenExpiredException();
    }

    return response.statusCode == 200;
  }

  CardAsset _resolveAssetUrl(CardAsset asset, String baseUrl) {
    final url = asset.imageUrl;
    if (url == null || url.isEmpty) {
      return asset;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return asset;
    }
    final resolved =
        url.startsWith('/') ? '$baseUrl$url' : '$baseUrl/$url';
    return asset.copyWith(imageUrl: resolved);
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
