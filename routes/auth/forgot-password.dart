import 'dart:convert';
import 'dart:io';

import 'package:cawil_backend/auth/reset_token.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return jsonError(405, 'Method not allowed');
  }

  try {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final email = body['email'] as String?;

    if (email == null || email.trim().isEmpty) {
      return jsonError(400, 'email is required');
    }

    final db = CaWilDatabase.instance;
    final user = await userByEmail(db, email);
    String? resetToken;

    if (user != null) {
      resetToken = generatePasswordResetToken();
      await createPasswordResetToken(
        db,
        userId: user.id,
        tokenHash: hashPasswordResetToken(resetToken),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );
    }

    return jsonResponse({
      'message':
          'If an account exists for this email, a reset token has been created.',
      if (resetToken != null && _shouldReturnResetToken())
        'reset_token': resetToken,
    });
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

bool _shouldReturnResetToken() {
  final value = Platform.environment['RETURN_PASSWORD_RESET_TOKEN'] ?? 'true';
  return value.toLowerCase() != 'false';
}
