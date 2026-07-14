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
    final body =
        jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final scheduleId = body['schedule_id'] as int?;
    final seatNumbers = _parseSeatNumbers(body);
    final contactPerson =
        _optionalString(body['contact_person'] ?? body['passenger_name']);
    final phone = _optionalString(body['phone']);
    final totalPrice = (body['total_price'] as num?)?.toDouble();

    if (scheduleId == null ||
        seatNumbers.isEmpty ||
        contactPerson == null ||
        contactPerson.trim().isEmpty ||
        phone == null ||
        phone.trim().isEmpty ||
        totalPrice == null) {
      return jsonError(
        400,
        'schedule_id, seat_numbers, contact_person, phone, and total_price are required',
      );
    }

    final db = CaWilDatabase.instance;
    final userId = payload['sub'] as int;

    final result = await createBooking(
      db,
      userId: userId,
      scheduleId: scheduleId,
      seatNumbers: seatNumbers,
      contactPerson: contactPerson,
      phone: phone,
      totalPrice: totalPrice,
    );

    return jsonResponse(result, statusCode: 201);
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('No seats available')) {
      return jsonError(409, msg);
    }
    if (msg.contains('Seat already booked')) {
      return jsonError(409, msg);
    }
    if (msg.contains('Schedule not found')) {
      return jsonError(404, msg);
    }
    return jsonError(400, msg);
  }
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  return value.toString();
}

List<String> _parseSeatNumbers(Map<String, dynamic> body) {
  final seatNumbers = body['seat_numbers'];
  if (seatNumbers is List) {
    return seatNumbers
        .map((seat) => seat.toString().trim())
        .where((seat) => seat.isNotEmpty)
        .toList(growable: false);
  }

  final seatNumber = body['seat_number'];
  if (seatNumber is String && seatNumber.trim().isNotEmpty) {
    return [seatNumber.trim()];
  }

  return const [];
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final secret = Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyBearerToken(context.request.headers, secret);
}
