import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? email;

  const AuthSession({
    required this.accessToken,
    this.idToken,
    this.refreshToken,
    this.expiresAt,
    this.email,
  });

  bool get isExpired {
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(expiresAt!);
  }
}

class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage, SharedPreferences? prefs})
      : _storage = storage ?? const FlutterSecureStorage(),
        _prefs = prefs;

  final FlutterSecureStorage _storage;
  final SharedPreferences? _prefs;

  static const _keyAccessToken = 'access_token';
  static const _keyIdToken = 'id_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyExpiresAt = 'expires_at';
  static const _keyEmail = 'email';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<void> save(AuthSession session) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.setString(_keyAccessToken, session.accessToken);
      if (session.idToken != null) {
        await prefs.setString(_keyIdToken, session.idToken!);
      } else {
        await prefs.remove(_keyIdToken);
      }
      if (session.refreshToken != null) {
        await prefs.setString(_keyRefreshToken, session.refreshToken!);
      } else {
        await prefs.remove(_keyRefreshToken);
      }
      if (session.expiresAt != null) {
        final expires = session.expiresAt!.toUtc().millisecondsSinceEpoch.toString();
        await prefs.setString(_keyExpiresAt, expires);
      } else {
        await prefs.remove(_keyExpiresAt);
      }
      if (session.email != null) {
        await prefs.setString(_keyEmail, session.email!);
      } else {
        await prefs.remove(_keyEmail);
      }
      debugPrint(
        'WEB session saved access=${session.accessToken.length} id=${session.idToken?.length ?? 0}',
      );
      return;
    }

    await _storage.write(key: _keyAccessToken, value: session.accessToken);
    if (session.idToken != null) {
      await _storage.write(key: _keyIdToken, value: session.idToken);
    } else {
      await _storage.delete(key: _keyIdToken);
    }
    if (session.refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: session.refreshToken);
    } else {
      await _storage.delete(key: _keyRefreshToken);
    }
    if (session.expiresAt != null) {
      final expires = session.expiresAt!.toUtc().millisecondsSinceEpoch.toString();
      await _storage.write(key: _keyExpiresAt, value: expires);
    }
    if (session.email != null) {
      await _storage.write(key: _keyEmail, value: session.email);
    }
  }

  Future<AuthSession?> read() async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      final accessToken = prefs.getString(_keyAccessToken);
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('WEB session read: empty.');
        return null;
      }

      final idToken = prefs.getString(_keyIdToken);
      final refreshToken = prefs.getString(_keyRefreshToken);
      final expiresRaw = prefs.getString(_keyExpiresAt);
      final email = prefs.getString(_keyEmail);

      DateTime? expiresAt;
      if (expiresRaw != null && expiresRaw.isNotEmpty) {
        final milliseconds = int.tryParse(expiresRaw);
        if (milliseconds != null) {
          expiresAt = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
        }
      }

      return AuthSession(
        accessToken: accessToken,
        idToken: idToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        email: email,
      );
    }

    final accessToken = await _storage.read(key: _keyAccessToken);
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final idToken = await _storage.read(key: _keyIdToken);
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    final expiresRaw = await _storage.read(key: _keyExpiresAt);
    final email = await _storage.read(key: _keyEmail);

    DateTime? expiresAt;
    if (expiresRaw != null && expiresRaw.isNotEmpty) {
      final milliseconds = int.tryParse(expiresRaw);
      if (milliseconds != null) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
      }
    }

    return AuthSession(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      email: email,
    );
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyIdToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyExpiresAt);
      await prefs.remove(_keyEmail);
      debugPrint('WEB session cleared.');
      return;
    }

    await _storage.deleteAll();
  }
}
