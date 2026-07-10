import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final parsedId = int.tryParse(id);
  if (parsedId == null) {
    return jsonError(400, 'Invalid route ID');
  }

  try {
    switch (context.request.method) {
      case HttpMethod.put:
        return _updateRoute(context, parsedId);
      case HttpMethod.delete:
        return _deleteRoute(context, parsedId);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Future<Response> _updateRoute(RequestContext context, int id) async {
  final body =
      jsonDecode(await context.request.body()) as Map<String, dynamic>;

  final db = CaWilDatabase.instance;
  final route = await updateRoute(
    db,
    id,
    origin: body['origin'] as String?,
    destination: body['destination'] as String?,
    durationHours: (body['duration_hours'] as num?)?.toDouble(),
    basePrice: (body['base_price'] as num?)?.toDouble(),
    status: body['status'] as String?,
  );
  return jsonResponse(route.toJson());
}

Future<Response> _deleteRoute(RequestContext context, int id) async {
  final db = CaWilDatabase.instance;
  final existing = await getRouteById(db, id);
  if (existing == null) {
    return jsonError(404, 'Route not found');
  }
  await deleteRoute(db, id);
  return jsonResponse({'status': 'deleted'});
}
