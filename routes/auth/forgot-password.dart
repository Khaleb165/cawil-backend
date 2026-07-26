import 'dart:convert';
import 'dart:io';

import 'package:cawil_backend/auth/reset_token.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/email/password_reset_mailer.dart';
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

      if (_shouldSendResetEmail()) {
        try {
          await PasswordResetMailer().sendPasswordResetEmail(
            toEmail: user.email,
            username: user.username,
            token: resetToken,
          );
        } catch (error, stackTrace) {
          print('Failed to send password reset email: $error');
          print(stackTrace);
          return jsonError(
            500,
            'Unable to send password reset email. Please try again later.',
          );
        }
      }
    }

    return jsonResponse({
      'message':
          'If an account exists for this email, a password reset email has been sent.',
      if (resetToken != null && _shouldReturnResetToken())
        'reset_token': resetToken,
    });
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

bool _shouldSendResetEmail() {
  final value = Platform.environment['SEND_PASSWORD_RESET_EMAIL'] ?? 'true';
  return value.toLowerCase() != 'false' && value != '0';
}

bool _shouldReturnResetToken() {
  final value = Platform.environment['RETURN_PASSWORD_RESET_TOKEN'] ?? 'false';
  return value.toLowerCase() == 'true' || value == '1';
}
