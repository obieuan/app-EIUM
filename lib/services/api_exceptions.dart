class TokenExpiredException implements Exception {
  const TokenExpiredException();

  @override
  String toString() => 'Token expired';
}
