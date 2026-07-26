import 'dart:convert';

import 'package:cawil_backend/auth/password.dart';
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
    final token = body['token'] as String?;
    final password = body['password'] as String?;

    if (token == null || token.trim().isEmpty) {
      return jsonError(400, 'token is required');
    }
    if (password == null || password.length < 6) {
      return jsonError(400, 'password must be at least 6 characters');
    }

    final db = CaWilDatabase.instance;
    final tokenHash = hashPasswordResetToken(token.trim());
    final userId = await getValidPasswordResetUserId(db, tokenHash);
    if (userId == null) {
      return jsonError(401, 'Invalid or expired reset token');
    }

    await updatePassword(db, userId, hashPassword(password));
    await markPasswordResetTokenUsed(db, tokenHash);
    await revokeRefreshTokensForUser(db, userId);

    return jsonResponse({
      'message': 'Password reset successfully',
    });
  } catch (e) {
    return jsonError(400, e.toString());
  }
}
