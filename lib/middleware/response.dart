import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';

Response jsonResponse(Object body, {int statusCode = 200}) {
  return Response(
    statusCode: statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}

Response jsonError(int statusCode, String message) {
  return jsonResponse({'error': message}, statusCode: statusCode);
}
