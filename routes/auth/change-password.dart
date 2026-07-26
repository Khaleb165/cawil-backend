import 'dart:convert';
import 'dart:io';

import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/auth/password.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return jsonError(405, 'Method not allowed');
  }

  final secret = Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  final payload = verifyBearerToken(context.request.headers, secret);
  if (payload == null) {
    return jsonError(401, 'Authentication required');
  }

  try {
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final currentPassword = body['current_password'] as String?;
    final newPassword = body['new_password'] as String?;

    if (currentPassword == null || newPassword == null) {
      return jsonError(400, 'current_password and new_password are required');
    }
    if (newPassword.length < 6) {
      return jsonError(400, 'New password must be at least 6 characters');
    }

    final userId = payload['sub'] as int;
    final db = CaWilDatabase.instance;
    final user = await userById(db, userId);
    if (user == null) {
      return jsonError(404, 'User not found');
    }

    if (!verifyPassword(currentPassword, user.passwordHash)) {
      return jsonError(401, 'Current password is incorrect');
    }

    await updatePassword(db, userId, hashPassword(newPassword));
    await revokeRefreshTokensForUser(db, userId);

    return jsonResponse({'message': 'Password updated successfully'});
  } catch (e) {
    return jsonError(400, e.toString());
  }
}
