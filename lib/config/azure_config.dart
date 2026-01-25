import 'package:flutter/foundation.dart';

import 'app_config.dart';

class AzureConfig {
  static String get clientId => AppConfig.azureClientId;
  static String get tenantId => AppConfig.azureTenantId;
  static String get redirectUriMobile => AppConfig.azureRedirectUriMobile;
  static String get redirectUriWeb => AppConfig.azureRedirectUriWeb;
  static String get redirectUri {
    if (kIsWeb) {
      return redirectUriWeb.isNotEmpty ? redirectUriWeb : redirectUriMobile;
    }
    return redirectUriMobile.isNotEmpty ? redirectUriMobile : redirectUriWeb;
  }

  static String get discoveryUrl {
    if (tenantId.isEmpty) {
      return '';
    }
    return 'https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration';
  }

  static String get issuerUrl {
    if (tenantId.isEmpty) {
      return '';
    }
    return 'https://login.microsoftonline.com/$tenantId/v2.0';
  }

  static List<String> get scopes => const [
        'openid',
        'profile',
        'email',
        'offline_access',
      ];
}
