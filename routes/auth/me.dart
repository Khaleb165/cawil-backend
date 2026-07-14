import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  final payload = _getAuthPayload(context);
  if (payload == null) {
    return jsonError(401, 'Authentication required');
  }

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return _getProfile(context, payload);
      case HttpMethod.put:
        return _updateProfile(context, payload);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final secret = Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyBearerToken(context.request.headers, secret);
}

Future<Response> _getProfile(
    RequestContext context, Map<String, dynamic> payload) async {
  final db = CaWilDatabase.instance;
  final userId = payload['sub'] as int;
  final user = await userById(db, userId);

  if (user == null) {
    return jsonError(404, 'User not found');
  }

  return jsonResponse({'user': user.toJson()});
}

Future<Response> _updateProfile(
    RequestContext context, Map<String, dynamic> payload) async {
  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;

  final username = body['username'] as String?;
  final avatarUrl = body['avatar_url'] as String?;

  if (username == null && avatarUrl == null) {
    return jsonError(400, 'Nothing to update');
  }

  final db = CaWilDatabase.instance;
  final userId = payload['sub'] as int;

  await updateUser(db, userId, username: username, avatarUrl: avatarUrl);

  final user = await userById(db, userId);
  if (user == null) {
    return jsonError(404, 'User not found');
  }

  return jsonResponse({'user': user.toJson()});
}
