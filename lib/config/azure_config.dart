import 'package:flutter_dotenv/flutter_dotenv.dart';

class AzureConfig {
  static String get clientId => dotenv.env['AZURE_CLIENT_ID'] ?? '';
  static String get tenantId => dotenv.env['AZURE_TENANT_ID'] ?? '';
  static String get redirectUri => dotenv.env['AZURE_REDIRECT_URI'] ?? '';

  static String get discoveryUrl {
    if (tenantId.isEmpty) {
      return '';
    }
    return 'https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration';
  }

  static List<String> get scopes => const [
        'openid',
        'profile',
        'email',
        'offline_access',
      ];
}
