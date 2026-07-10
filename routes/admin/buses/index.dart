import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return _listBuses(context);
      case HttpMethod.post:
        return _createBus(context);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Future<Response> _listBuses(RequestContext context) async {
  final db = CaWilDatabase.instance;
  final buses = await listBuses(db);
  return jsonResponse(buses.map((b) => b.toJson()).toList());
}

Future<Response> _createBus(RequestContext context) async {
  final body =
      jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final busNumber = body['bus_number'] as String?;
  if (busNumber == null || busNumber.trim().isEmpty) {
    return jsonError(400, 'bus_number is required');
  }

  final db = CaWilDatabase.instance;
  final bus = await createBus(
    db,
    busNumber: busNumber,
    plateNumber: body['plate_number'] as String?,
    totalSeats: body['total_seats'] as int? ?? 32,
    routeType: body['route_type'] as String? ?? 'long-distance',
  );
  return jsonResponse(bus.toJson(), statusCode: 201);
}
