import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final parsedId = int.tryParse(id);
  if (parsedId == null) {
    return jsonError(400, 'Invalid bus ID');
  }

  try {
    switch (context.request.method) {
      case HttpMethod.put:
        return _updateBus(context, parsedId);
      case HttpMethod.delete:
        return _deleteBus(context, parsedId);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Future<Response> _updateBus(RequestContext context, int id) async {
  final body =
      jsonDecode(await context.request.body()) as Map<String, dynamic>;

  final db = CaWilDatabase.instance;
  final bus = await updateBus(
    db,
    id,
    busNumber: body['bus_number'] as String?,
    plateNumber: body['plate_number'] as String?,
    totalSeats: body['total_seats'] as int?,
    status: body['status'] as String?,
  );
  return jsonResponse(bus.toJson());
}

Future<Response> _deleteBus(RequestContext context, int id) async {
  final db = CaWilDatabase.instance;
  final existing = await getBusById(db, id);
  if (existing == null) {
    return jsonError(404, 'Bus not found');
  }
  await deleteBus(db, id);
  return jsonResponse({'status': 'deleted'});
}
