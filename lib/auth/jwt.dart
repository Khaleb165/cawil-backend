import 'dart:convert';
import 'package:crypto/crypto.dart';

String _base64url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

String generateJwt(Map<String, dynamic> payload, String secret) {
  final header = _base64url(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final encodedPayload = _base64url(utf8.encode(jsonEncode(payload)));
  final signature = _base64url(
    Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('$header.$encodedPayload'))
        .bytes,
  );
  return '$header.$encodedPayload.$signature';
}

Map<String, dynamic>? verifyJwt(String token, String secret) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    final expectedSig = _base64url(
      Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode('${parts[0]}.${parts[1]}'))
          .bytes,
    );

    if (expectedSig != parts[2]) return null;

    final payload = jsonDecode(utf8.decode(base64Url.decode(parts[1])))
        as Map<String, dynamic>;

    final exp = payload['exp'] as int?;
    if (exp != null && DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp) {
      return null;
    }

    return payload;
  } catch (_) {
    return null;
  }
}
