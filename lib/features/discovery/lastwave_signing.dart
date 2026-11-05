import 'dart:convert';

import 'package:crypto/crypto.dart';

/// LastWave-style HTTP add-ons put a private listener token in /a/<token>.
/// The published client protocol signs API requests with a common shared key.
/// This key is not a user secret; only the listener's URL is private.
/// Other HTTP add-ons remain entirely unsigned.
const _defaultSigningKey = String.fromEnvironment(
  'LASTWAVE_ADDON_SIGNING_SECRET',
  defaultValue:
      '36d96a751b12ee481c281a8a8e64c482d0c1634a22061ab72f40175017818b85',
);

Map<String, String> lastWaveHeaders(
  Uri url, {
  String? intent,
  int? epochSeconds,
  String signingKey = _defaultSigningKey,
}) {
  if (url.scheme != 'https' || signingKey.isEmpty) return const {};
  final parts = url.pathSegments;
  final index = parts.indexOf('a');
  if (index < 0 || index + 1 >= parts.length) return const {};
  final token = parts[index + 1];
  if (token.isEmpty) return const {};

  final seconds =
      epochSeconds ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  // LastWave signs the decoded URI path, not the query string or host.
  final message = seconds.toString() + '\nGET\n' + url.path + '\n' + token;
  final signature = Hmac(sha256, utf8.encode(signingKey))
      .convert(utf8.encode(message))
      .toString();
  return {
    'X-LW-TS': seconds.toString(),
    'X-LW-Sign': signature,
    if (intent == 'stream' || intent == 'download') 'X-LW-Intent': intent!,
  };
}
