import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/auth/password.dart';
import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return jsonError(405, 'Method not allowed');
  }

  try {
    final body = jsonDecode(await context.request.body())
        as Map<String, dynamic>;
    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (email == null || password == null) {
      return jsonError(400, 'email and password are required');
    }

    final db = CaWilDatabase.instance;

    final user = await userByEmail(db, email);
    if (user == null) {
      return jsonError(401, 'Invalid email or password');
    }

    if (!verifyPassword(password, user.passwordHash)) {
      return jsonError(401, 'Invalid email or password');
    }

    final jwtSecret =
        Platform.environment['JWT_SECRET'] ?? 'dev-secret';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final accessToken = generateJwt({
      'sub': user.id,
      'email': user.email,
      'role': user.role,
      'iat': now,
      'exp': now + 3600,
    }, jwtSecret);

    final uuid = Uuid();
    final jti = uuid.v4();
    final refreshExpires = DateTime.now().add(const Duration(days: 30));

    await createRefreshToken(db, user.id, jti, refreshExpires);

    final refreshToken = generateJwt({
      'sub': user.id,
      'jti': jti,
      'iat': now,
      'exp': refreshExpires.millisecondsSinceEpoch ~/ 1000,
    }, jwtSecret);

    return jsonResponse({
      'user': user.toJson(),
      'access_token': accessToken,
      'refresh_token': refreshToken,
    });
  } catch (e) {
    return jsonError(400, e.toString());
  }
}
