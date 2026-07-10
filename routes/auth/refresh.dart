import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return jsonError(405, 'Method not allowed');
  }

  try {
    final body = jsonDecode(await context.request.body())
        as Map<String, dynamic>;
    final refreshTokenStr = body['refresh_token'] as String?;

    if (refreshTokenStr == null) {
      return jsonError(400, 'refresh_token is required');
    }

    final jwtSecret =
        Platform.environment['JWT_SECRET'] ?? 'dev-secret';
    final payload = verifyJwt(refreshTokenStr, jwtSecret);

    if (payload == null) {
      return jsonError(401, 'Invalid or expired refresh token');
    }

    final jti = payload['jti'] as String?;
    if (jti == null) {
      return jsonError(401, 'Invalid refresh token payload');
    }

    final db = CaWilDatabase.instance;

    final stored = await getValidRefreshToken(db, jti);
    if (stored == null) {
      return jsonError(401, 'Refresh token has been revoked or expired');
    }

    await revokeRefreshToken(db, jti);

    final user = await userById(db, stored.userId);
    if (user == null) {
      return jsonError(401, 'User not found');
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final newAccessToken = generateJwt({
      'sub': user.id,
      'email': user.email,
      'role': user.role,
      'iat': now,
      'exp': now + 3600,
    }, jwtSecret);

    final uuid = Uuid();
    final newJti = uuid.v4();
    final refreshExpires = DateTime.now().add(const Duration(days: 30));

    await createRefreshToken(db, user.id, newJti, refreshExpires);

    final newRefreshToken = generateJwt({
      'sub': user.id,
      'jti': newJti,
      'iat': now,
      'exp': refreshExpires.millisecondsSinceEpoch ~/ 1000,
    }, jwtSecret);

    return jsonResponse({
      'access_token': newAccessToken,
      'refresh_token': newRefreshToken,
    });
  } catch (e) {
    return jsonError(400, e.toString());
  }
}
