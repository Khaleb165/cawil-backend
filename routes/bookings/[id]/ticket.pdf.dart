import 'dart:io';
import 'dart:typed_data';

import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';
import 'package:cawil_backend/tickets/ticket_pdf.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  try {
    if (context.request.method != HttpMethod.get) {
      return jsonError(405, 'Method not allowed');
    }

    final parsedId = int.tryParse(id);
    if (parsedId == null) {
      return jsonError(400, 'Invalid booking ID');
    }

    final payload = _getAuthPayload(context);
    if (payload == null) {
      return jsonError(401, 'Authentication required');
    }

    final db = CaWilDatabase.instance;
    final ticket = await getTicketByBookingId(db, parsedId);
    if (ticket == null) {
      return jsonError(404, 'Booking not found');
    }

    final userId = _payloadUserId(payload);
    if (userId == null) {
      return jsonError(401, 'Invalid authentication token');
    }

    final role = payload['role'] as String?;
    if (ticket['user_id'] != userId && role != 'admin') {
      return jsonError(403, 'Only owner or admin can download this ticket');
    }

    if (ticket['payment_status'] != 'completed') {
      return jsonError(409, 'Ticket is available after payment is completed');
    }

    var pdfBytes = ticket['qr_data'] as List<int>;
    if (pdfBytes.isEmpty) {
      pdfBytes = await buildTicketPdf(ticket);
      await updateBookingGroupPdf(
        db,
        ticket['booking_ref'] as String,
        pdfBytes,
      );
    }

    final bookingRef = ticket['booking_ref'];
    return Response.bytes(
      body: Uint8List.fromList(pdfBytes),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/pdf',
        HttpHeaders.contentLengthHeader: pdfBytes.length.toString(),
        'content-disposition':
            'attachment; filename="cawil-ticket-$bookingRef.pdf"',
      },
    );
  } catch (error, stackTrace) {
    print('Failed to build ticket PDF response: $error');
    print(stackTrace);
    return jsonError(500, 'Failed to generate ticket PDF');
  }
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final secret = Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyBearerToken(context.request.headers, secret);
}

int? _payloadUserId(Map<String, dynamic> payload) {
  final sub = payload['sub'];
  if (sub is int) return sub;
  if (sub is num) return sub.toInt();
  if (sub is String) return int.tryParse(sub);
  return null;
}
