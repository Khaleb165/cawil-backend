import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cawil_backend/auth/jwt.dart';

Handler middleware(Handler handler) {
  return (context) async {
    final authHeader = context.request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(
        statusCode: 401,
        body: jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final token = authHeader.substring(7);
    final secret =
        Platform.environment['JWT_SECRET'] ?? 'dev-secret';
    final payload = verifyJwt(token, secret);

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
