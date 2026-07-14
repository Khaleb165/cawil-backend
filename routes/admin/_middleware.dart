import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cawil_backend/auth/jwt.dart';

Handler middleware(Handler handler) {
  return (context) async {
    final secret = Platform.environment['JWT_SECRET'] ?? 'dev-secret';
    final payload = verifyBearerToken(context.request.headers, secret);

    if (payload == null) {
      return Response(
        statusCode: 401,
        body: jsonEncode({'error': 'Invalid or expired token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (payload['role'] != 'admin') {
      return Response(
        statusCode: 403,
        body: jsonEncode({'error': 'Admin access required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return handler(context);
  };
}
