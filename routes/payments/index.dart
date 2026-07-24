import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';
import 'package:cawil_backend/payments/paystack.dart';
import 'package:dart_frog/dart_frog.dart';

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
    final contactPerson = body['contact_person']?.toString().trim();
    final phone = body['phone']?.toString().trim();
    final paymentMethod = body['payment_method']?.toString();

    if (scheduleId == null ||
        seatNumbers.isEmpty ||
        contactPerson == null ||
        contactPerson.isEmpty ||
        phone == null ||
        phone.isEmpty) {
      return jsonError(
        400,
        'schedule_id, seat_numbers, contact_person, and phone are required',
      );
    }

    final db = CaWilDatabase.instance;
    final userId = payload['sub'] as int;
    final user = await userById(db, userId);
    if (user == null) {
      return jsonError(401, 'User not found');
    }

    final schedule = await getScheduleById(db, scheduleId);
    if (schedule == null) {
      return jsonError(404, 'Schedule not found');
    }

    final totalPrice = schedule.price * seatNumbers.length;

    Map<String, dynamic>? booking;
    try {
      booking = await createBooking(
        db,
        userId: userId,
        scheduleId: scheduleId,
        seatNumbers: seatNumbers,
        contactPerson: contactPerson,
        phone: phone,
        totalPrice: totalPrice,
      );

      final paystack = PaystackClient();
      final reference = _paymentReference();
      final initialized = await paystack.initializeTransaction(
        email: user.email,
        amount: totalPrice,
        reference: reference,
        bookingRef: booking['booking_ref'] as String,
        seatNumbers: seatNumbers,
        paymentMethod: paymentMethod,
      );

      final payment = await createPayment(
        db,
        userId: userId,
        bookingRef: booking['booking_ref'] as String,
        providerReference: initialized['reference']?.toString() ?? reference,
        amount: totalPrice,
        currency: paystack.currency,
        authorizationUrl: initialized['authorization_url']?.toString(),
        accessCode: initialized['access_code']?.toString(),
        providerPayload: initialized,
      );

      return jsonResponse(
        {
          'booking': booking,
          'payment': payment.toJson(),
          'authorization_url': payment.authorizationUrl,
          'access_code': payment.accessCode,
          'reference': payment.providerReference,
        },
        statusCode: 201,
      );
    } catch (_) {
      final createdBooking = booking;
      if (createdBooking != null) {
        await cancelBooking(
          db,
          createdBooking['id'] as int,
          userId,
        );
      }
      rethrow;
    }
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('No seats available') ||
        msg.contains('Seat already booked')) {
      return jsonError(409, msg);
    }
    if (msg.contains('not found')) {
      return jsonError(404, msg);
    }
    return jsonError(400, msg);
  }
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final secret = Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyBearerToken(context.request.headers, secret);
}

List<String> _parseSeatNumbers(Map<String, dynamic> body) {
  final seatNumbers = body['seat_numbers'];
  if (seatNumbers is List) {
    return seatNumbers
        .map((seat) => seat.toString().trim())
        .where((seat) => seat.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

String _paymentReference() {
  final now = DateTime.now();
  final random = Random.secure();
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final suffix = List.generate(
    8,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
  return 'CAW-PAY-${now.millisecondsSinceEpoch}-$suffix';
}
