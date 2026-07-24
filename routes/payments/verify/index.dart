import 'dart:convert';
import 'dart:io';

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
    final reference = body['reference']?.toString().trim();
    if (reference == null || reference.isEmpty) {
      return jsonError(400, 'reference is required');
    }

    final db = CaWilDatabase.instance;
    final payment = await getPaymentByReference(db, reference);
    if (payment == null) {
      return jsonError(404, 'Payment not found');
    }

    final userId = payload['sub'] as int;
    final role = payload['role'] as String?;
    if (payment.userId != userId && role != 'admin') {
      return jsonError(403, 'Only owner or admin can verify this payment');
    }

    final paystack = PaystackClient();
    final verified = await paystack.verifyTransaction(reference);
    final amount = ((verified['amount'] as num?) ?? 0).toInt() / 100;
    final currency = verified['currency']?.toString().toUpperCase();

    if ((amount - payment.amount).abs() > 0.01 ||
        currency != payment.currency.toUpperCase()) {
      return jsonError(409, 'Payment amount or currency mismatch');
    }

    final updated = await updatePaymentFromProvider(
      db,
      providerReference: reference,
      status: verified['status']?.toString() ?? 'pending',
      channel: verified['channel']?.toString(),
      gatewayResponse: verified['gateway_response']?.toString(),
      paidAt: _parseDateTime(verified['paid_at']),
      providerPayload: verified,
    );

    return jsonResponse({
      'payment': updated.toJson(),
      'paystack_status': verified['status'],
    });
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final secret = Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyBearerToken(context.request.headers, secret);
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}
