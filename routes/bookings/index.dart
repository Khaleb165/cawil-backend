import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return jsonError(405, 'Method not allowed');
  }

  final payload = _getAuthPayload(context);
  if (payload == null) {
    return jsonError(401, 'Authentication required');
  }

  try {
    final body = jsonDecode(await context.request.body())
        as Map<String, dynamic>;
    final scheduleId = body['schedule_id'] as int?;
    final seatNumber = body['seat_number'] as String?;
    final passengerName = body['passenger_name'] as String?;
    final phone = body['phone'] as String?;
    final totalPrice = (body['total_price'] as num?)?.toDouble();

    if (scheduleId == null ||
        seatNumber == null ||
        passengerName == null ||
        phone == null ||
        totalPrice == null) {
      return jsonError(
        400,
        'schedule_id, seat_number, passenger_name, phone, and total_price are required',
      );
    }

    final db = CaWilDatabase.instance;
    final userId = payload['sub'] as int;

    final result = await createBooking(
      db,
      userId: userId,
      scheduleId: scheduleId,
      seatNumber: seatNumber,
      passengerName: passengerName,
      phone: phone,
      totalPrice: totalPrice,
    );

    return jsonResponse(result, statusCode: 201);
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('No seats available')) {
      return jsonError(409, msg);
    }
    if (msg.contains('Schedule not found')) {
      return jsonError(404, msg);
    }
    return jsonError(400, msg);
  }
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final authHeader = context.request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  final token = authHeader.substring(7);
  final secret =
      Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyJwt(token, secret);
}
