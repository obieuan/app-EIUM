import 'dart:convert';

Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('Invalid JWT token format.');
  }

  final normalized = base64Url.normalize(parts[1]);
  final payloadBytes = base64Url.decode(normalized);
  final payloadString = utf8.decode(payloadBytes);
  final payload = json.decode(payloadString);

  if (payload is Map<String, dynamic>) {
    return payload;
  }
  return <String, dynamic>{};
}
