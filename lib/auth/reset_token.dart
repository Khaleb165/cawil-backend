import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String generatePasswordResetToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

String hashPasswordResetToken(String token) {
  return sha256.convert(utf8.encode(token)).toString();
}
