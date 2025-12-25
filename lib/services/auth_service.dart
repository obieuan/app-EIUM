import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/azure_config.dart';

class AuthResult {
  final String accessToken;
  final String? idToken;

  const AuthResult({
    required this.accessToken,
    this.idToken,
  });
}

class AuthService {
  AuthService({FlutterAppAuth? appAuth}) : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  Future<AuthResult?> signIn() async {
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

    return AuthResult(
      accessToken: response.accessToken!,
      idToken: response.idToken,
    );
  }
}
