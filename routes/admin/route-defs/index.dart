import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return _listRoutes(context);
      case HttpMethod.post:
        return _createRoute(context);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Future<Response> _listRoutes(RequestContext context) async {
  final db = CaWilDatabase.instance;
  final routes = await listRoutes(db);
  return jsonResponse(routes.map((r) => r.toJson()).toList());
}

Future<Response> _createRoute(RequestContext context) async {
  final body =
      jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final origin = body['origin'] as String?;
  final destination = body['destination'] as String?;

  if (origin == null || destination == null) {
    return jsonError(400, 'origin and destination are required');
  }

  final db = CaWilDatabase.instance;
  final route = await createRoute(
    db,
    origin: origin,
    destination: destination,
    durationHours: (body['duration_hours'] as num?)?.toDouble(),
    basePrice: (body['base_price'] as num?)?.toDouble(),
  );
  return jsonResponse(route.toJson(), statusCode: 201);
}
