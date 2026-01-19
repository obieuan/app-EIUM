import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:openid_client/openid_client.dart';
import 'package:openid_client/openid_client_browser.dart' as oidc;

import '../config/azure_config.dart';
import '../utils/jwt_utils.dart';
import 'session_storage.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    FlutterAppAuth? appAuth,
    SessionStorage? sessionStorage,
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _sessionStorage = sessionStorage ?? SessionStorage();

  final FlutterAppAuth _appAuth;
  final SessionStorage _sessionStorage;
  static const Duration _tokenLeeway = Duration(seconds: 30);

  Future<bool> checkAppStatus() async {
    try {
      final baseUrl = dotenv.env['EVENTS_API_BASE_URL'] ?? 'http://127.0.0.1:8000';
      final uri = Uri.parse('$baseUrl/api/vnext/status');
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['maintenance'] == true;
      }
    } catch (e) {
      debugPrint('Error checking app status: $e');
    }
    return false; // Default to available if check fails
  }

  Future<AuthSession?> getValidSession() async {
    final session = await _sessionStorage.read();
    if (session == null) {
      return null;
    }
    if (_isSessionExpired(session)) {
      final refreshed = await _refreshSession(session);
      if (refreshed == null) {
        await _sessionStorage.clear();
        return null;
      }
      return refreshed;
    }
    return session;
  }

  Future<AuthSession?> refreshSession() async {
    final session = await _sessionStorage.read();
    if (session == null) {
      return null;
    }
    final refreshed = await _refreshSession(session);
    if (refreshed == null) {
      await _sessionStorage.clear();
    }
    return refreshed;
  }

  Future<AuthSession?> completeWebSignInIfNeeded() async {
    if (!kIsWeb) {
      return null;
    }
    if (AzureConfig.clientId.isEmpty ||
        AzureConfig.tenantId.isEmpty ||
        AzureConfig.issuerUrl.isEmpty) {
      debugPrint('WEB auth: missing Azure config (client/tenant/issuer).');
      return null;
    }

    debugPrint('WEB auth: checking redirect credential.');
    debugPrint('WEB auth: current url=${Uri.base}');

    final fallbackSession = _sessionFromFragment();
    if (fallbackSession != null) {
      await _sessionStorage.save(fallbackSession);
      return fallbackSession;
    }

    final issuer = await Issuer.discover(Uri.parse(AzureConfig.issuerUrl));
    final client = Client(issuer, AzureConfig.clientId);
    final authenticator = oidc.Authenticator(
      client,
      scopes: AzureConfig.scopes,
      prompt: 'select_account',
    );

    final credential = await authenticator.credential;
    if (credential == null) {
      debugPrint('WEB auth: no credential found in url.');
      return null;
    }

    final tokenResponse = await credential.getTokenResponse();
    final idToken = tokenResponse.idToken?.toString();
    if (idToken == null || idToken.isEmpty) {
      debugPrint('WEB auth: missing id_token in token response.');
      return null;
    }

    final email = _extractEmail(idToken);
    if (email == null || !_isAllowedDomain(email)) {
      debugPrint('WEB auth: email invalid or not allowed.');
      await _sessionStorage.clear();
      return null;
    }

    final accessToken = tokenResponse.accessToken?.toString() ?? idToken;
    debugPrint(
      'WEB auth: tokenResponse ok access=${accessToken.length} id=${idToken.length}',
    );
    final session = AuthSession(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: tokenResponse.refreshToken,
      expiresAt: tokenResponse.expiresAt,
      email: email,
    );
    await _sessionStorage.save(session);
    return session;
  }

  Future<void> signOut() async {
    await _sessionStorage.clear();
  }

  Future<AuthSession?> signIn() async {
    if (kIsWeb) {
      return _signInWeb();
    }

    if (AzureConfig.clientId.isEmpty ||
        AzureConfig.tenantId.isEmpty ||
        AzureConfig.redirectUri.isEmpty) {
      throw StateError('Azure config missing. Check the .env file.');
    }

    final response = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        AzureConfig.clientId,
        AzureConfig.redirectUri,
        discoveryUrl: AzureConfig.discoveryUrl,
        scopes: AzureConfig.scopes,
        promptValues: const ['select_account'],
      ),
    );

    if (response == null || response.accessToken == null) {
      return null;
    }

    if (response.idToken == null) {
      throw const AuthException('No se recibio el token de sesion.');
    }

    final email = _extractEmail(response.idToken!);
    if (email == null || !_isAllowedDomain(email)) {
      await _sessionStorage.clear();
      throw const AuthException('Solo cuentas @modelo.edu.mx.');
    }

    final session = AuthSession(
      accessToken: response.accessToken!,
      idToken: response.idToken,
      refreshToken: response.refreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
      email: email,
    );
    await _sessionStorage.save(session);
    return session;
  }

  String? _extractEmail(String token) {
    try {
      final payload = decodeJwtPayload(token);
      final email = payload['preferred_username'] ??
          payload['email'] ??
          payload['upn'];
      if (email is String && email.trim().isNotEmpty) {
        return email.trim();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isAllowedDomain(String email) {
    return email.toLowerCase().endsWith('@modelo.edu.mx');
  }

  bool _isSessionExpired(AuthSession session) {
    final now = DateTime.now();
    if (session.expiresAt != null &&
        now.isAfter(session.expiresAt!.subtract(_tokenLeeway))) {
      return true;
    }

    final idToken = session.idToken;
    if (idToken != null && idToken.isNotEmpty) {
      try {
        final payload = decodeJwtPayload(idToken);
        final exp = payload['exp'];
        if (exp is int) {
          final expAt =
              DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true).toLocal();
          if (now.isAfter(expAt.subtract(_tokenLeeway))) {
            return true;
          }
        }
      } catch (_) {
        return true;
      }
    }

    return false;
  }

  Future<AuthSession?> _refreshSession(AuthSession session) async {
    if (kIsWeb) {
      return null;
    }

    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    if (AzureConfig.clientId.isEmpty ||
        AzureConfig.redirectUri.isEmpty ||
        AzureConfig.discoveryUrl.isEmpty) {
      return null;
    }

    final response = await _appAuth.token(
      TokenRequest(
        AzureConfig.clientId,
        AzureConfig.redirectUri,
        discoveryUrl: AzureConfig.discoveryUrl,
        scopes: AzureConfig.scopes,
        refreshToken: refreshToken,
      ),
    );

    if (response == null || response.accessToken == null) {
      return null;
    }

    final idToken = response.idToken ?? session.idToken;
    if (idToken == null || idToken.isEmpty) {
      return null;
    }

    final email = _extractEmail(idToken);
    if (email == null || !_isAllowedDomain(email)) {
      return null;
    }

    final updated = AuthSession(
      accessToken: response.accessToken!,
      idToken: idToken,
      refreshToken: response.refreshToken ?? refreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
      email: email,
    );
    await _sessionStorage.save(updated);
    return updated;
  }

  Future<AuthSession?> _signInWeb() async {
    if (AzureConfig.clientId.isEmpty ||
        AzureConfig.tenantId.isEmpty ||
        AzureConfig.redirectUriWeb.isEmpty) {
      throw StateError('Azure config missing. Check the .env file.');
    }

    debugPrint('WEB auth: starting authorize flow.');
    final issuer = await Issuer.discover(Uri.parse(AzureConfig.issuerUrl));
    final client = Client(issuer, AzureConfig.clientId);
    final authenticator = oidc.Authenticator(
      client,
      scopes: AzureConfig.scopes,
      prompt: 'select_account',
    );

    final credential = await authenticator.credential;
    if (credential == null) {
      debugPrint('WEB auth: redirecting to Azure login.');
      authenticator.authorize();
      return null;
    }

    final tokenResponse = await credential.getTokenResponse();

    final idToken = tokenResponse.idToken?.toString();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('No se recibio el token de sesion.');
    }

    final email = _extractEmail(idToken);
    if (email == null || !_isAllowedDomain(email)) {
      await _sessionStorage.clear();
      throw const AuthException('Solo cuentas @modelo.edu.mx.');
    }

    final accessToken = tokenResponse.accessToken?.toString() ?? idToken;
    final session = AuthSession(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: tokenResponse.refreshToken,
      expiresAt: tokenResponse.expiresAt,
      email: email,
    );
    await _sessionStorage.save(session);
    return session;
  }

  AuthSession? _sessionFromFragment() {
    final fragment = Uri.base.fragment;
    if (fragment.isEmpty) {
      debugPrint('WEB auth: fragment empty.');
      return null;
    }

    Map<String, String> params;
    try {
      params = Uri.splitQueryString(fragment);
    } catch (_) {
      debugPrint('WEB auth: fragment parse failed.');
      return null;
    }

    final idToken = params['id_token'];
    if (idToken == null || idToken.isEmpty) {
      debugPrint('WEB auth: fragment missing id_token.');
      return null;
    }

    final email = _extractEmail(idToken);
    if (email == null || !_isAllowedDomain(email)) {
      debugPrint('WEB auth: fragment email invalid.');
      return null;
    }

    final accessToken = params['access_token'] ?? idToken;
    DateTime? expiresAt;
    final expiresRaw = params['expires_in'];
    if (expiresRaw != null) {
      final seconds = int.tryParse(expiresRaw);
      if (seconds != null) {
        expiresAt = DateTime.now().add(Duration(seconds: seconds));
      }
    }

    debugPrint(
      'WEB auth: fragment ok access=${accessToken.length} id=${idToken.length}',
    );
    return AuthSession(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: params['refresh_token'],
      expiresAt: expiresAt,
      email: email,
    );
  }
}
