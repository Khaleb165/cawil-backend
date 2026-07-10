import 'package:dart_frog/dart_frog.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/middleware/response.dart';
import 'dart:io';

Future<Response> onRequest(RequestContext context, String id) async {
  final parsedId = int.tryParse(id);
  if (parsedId == null) {
    return jsonError(400, 'Invalid booking ID');
  }

  final payload = _getAuthPayload(context);
  if (payload == null) {
    return jsonError(401, 'Authentication required');
  }

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return _getBooking(context, parsedId, payload);
      case HttpMethod.put:
        return _cancelBooking(context, parsedId, payload);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('not found')) {
      return jsonError(404, msg);
    }
    if (msg.contains('owner or admin')) {
      return jsonError(403, msg);
    }
    return jsonError(400, msg);
  }
}

Future<Response> _getBooking(
  RequestContext context,
  int id,
  Map<String, dynamic> payload,
) async {
  final db = CaWilDatabase.instance;
  final booking = await getBookingById(db, id);
  if (booking == null) {
    return jsonError(404, 'Booking not found');
  }

  final userId = payload['sub'] as int;
  final role = payload['role'] as String?;
  if (booking.userId != userId && role != 'admin') {
    return jsonError(403, 'Only owner or admin can view this booking');
  }

  return jsonResponse({
    'booking': booking.toJson(),
    'passenger_email': booking.email,
    'bus_number': booking.busNumber,
  });
}

Future<Response> _cancelBooking(
  RequestContext context,
  int id,
  Map<String, dynamic> payload,
) async {
  final db = CaWilDatabase.instance;
  final userId = payload['sub'] as int;
  final role = payload['role'] as String?;

  await cancelBooking(db, id, userId, isAdmin: role == 'admin');

  return jsonResponse({'status': 'cancelled'});
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final authHeader = context.request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  final token = authHeader.substring(7);
  final secret =
      Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyJwt(token, secret);
}
