import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const String _webAzureClientId =
      String.fromEnvironment('AZURE_CLIENT_ID', defaultValue: '');
  static const String _webAzureTenantId =
      String.fromEnvironment('AZURE_TENANT_ID', defaultValue: '');
  static const String _webAzureRedirectUriWeb =
      String.fromEnvironment('AZURE_REDIRECT_URI_WEB', defaultValue: '');
  static const String _webEventsApiBaseUrl =
      String.fromEnvironment('EVENTS_API_BASE_URL', defaultValue: '');
  static const String _webApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get azureClientId =>
      kIsWeb ? _webAzureClientId : const String.fromEnvironment('AZURE_CLIENT_ID');
  static String get azureTenantId =>
      kIsWeb ? _webAzureTenantId : const String.fromEnvironment('AZURE_TENANT_ID');
  static String get azureRedirectUriWeb =>
      kIsWeb ? _webAzureRedirectUriWeb : const String.fromEnvironment('AZURE_REDIRECT_URI_WEB');
  static String get azureRedirectUriMobile =>
      kIsWeb ? '' : const String.fromEnvironment('AZURE_REDIRECT_URI');

  static String get eventsApiBaseUrl =>
      kIsWeb ? _webEventsApiBaseUrl : const String.fromEnvironment('EVENTS_API_BASE_URL');
  static String get apiBaseUrl =>
      kIsWeb ? _webApiBaseUrl : const String.fromEnvironment('API_BASE_URL');
}
