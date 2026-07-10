import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/auth/jwt.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final parsedId = int.tryParse(id);
  if (parsedId == null) {
    return jsonError(400, 'Invalid schedule ID');
  }

  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return _getSchedule(context, parsedId);
      case HttpMethod.put:
        return _updateSchedule(context, parsedId);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Future<Response> _getSchedule(RequestContext context, int id) async {
  final db = CaWilDatabase.instance;
  final schedule = await getScheduleById(db, id);
  if (schedule == null) {
    return jsonError(404, 'Schedule not found');
  }

  return jsonResponse({
    'schedule': schedule.toJson(includeBus: false),
    'bus_info': {
      'bus_number': schedule.busNumber,
      'total_seats': schedule.totalSeats,
    },
  });
}

Future<Response> _updateSchedule(RequestContext context, int id) async {
  final payload = _getAuthPayload(context);
  if (payload == null) {
    return jsonError(401, 'Authentication required');
  }
  if (payload['role'] != 'admin') {
    return jsonError(403, 'Admin access required');
  }

  final body =
      jsonDecode(await context.request.body()) as Map<String, dynamic>;

  final seatsRemaining = body['seats_remaining'] as int?;
  if (seatsRemaining == null) {
    return jsonError(400, 'seats_remaining is required');
  }

  final db = CaWilDatabase.instance;
  await updateScheduleSeats(db, id, seatsRemaining);

  final schedule = await getScheduleById(db, id);
  if (schedule == null) {
    return jsonError(404, 'Schedule not found');
  }

  final adminId = payload['sub'] as int;
  await createAdminLog(
    db,
    adminId,
    'update_schedule_availability',
    targetType: 'schedule',
    targetId: id,
  );

  return jsonResponse({
    'schedule': schedule.toJson(includeBus: false),
    'bus_info': {
      'bus_number': schedule.busNumber,
      'total_seats': schedule.totalSeats,
    },
  });
}

Map<String, dynamic>? _getAuthPayload(RequestContext context) {
  final authHeader = context.request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  final token = authHeader.substring(7);
  final secret =
      Platform.environment['JWT_SECRET'] ?? 'dev-secret';
  return verifyJwt(token, secret);
}
