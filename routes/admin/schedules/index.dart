import 'dart:convert';

import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  try {
    switch (context.request.method) {
      case HttpMethod.get:
        return _listSchedules(context);
      case HttpMethod.post:
        return _createSchedule(context);
      default:
        return jsonError(405, 'Method not allowed');
    }
  } catch (e) {
    return jsonError(400, e.toString());
  }
}

Future<Response> _listSchedules(RequestContext context) async {
  final queryParams = context.request.uri.queryParameters;
  final dateStr = queryParams['date'];
  final busIdStr = queryParams['bus_id'];

  DateTime? date;
  if (dateStr != null && dateStr.isNotEmpty) {
    date = DateTime.tryParse(dateStr);
    if (date == null) {
      return jsonError(400, 'Invalid date format. Use YYYY-MM-DD');
    }
  }

  int? busId;
  if (busIdStr != null && busIdStr.isNotEmpty) {
    busId = int.tryParse(busIdStr);
    if (busId == null) {
      return jsonError(400, 'Invalid bus_id');
    }
  }

  final db = CaWilDatabase.instance;
  final schedules = await searchSchedules(
    db,
    origin: queryParams['origin'],
    destination: queryParams['destination'],
    date: date,
    busId: busId,
  );

  return jsonResponse(schedules.map(_scheduleResponse).toList());
}

Future<Response> _createSchedule(RequestContext context) async {
  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;

  final busId = _intFrom(body['bus_id']);
  final routeId = _intFrom(body['route_id']);
  final departureTime = _dateTimeFrom(body['departure_time']);

  if (busId == null || routeId == null || departureTime == null) {
    return jsonError(
      400,
      'bus_id, route_id, and departure_time are required',
    );
  }

  final db = CaWilDatabase.instance;
  final schedule = await createSchedule(
    db,
    busId: busId,
    routeId: routeId,
    departureTime: departureTime,
    arrivalTime: _dateTimeFrom(body['arrival_time']),
    price: _doubleFrom(body['price']),
    seatsRemaining: _intFrom(body['seats_remaining']),
  );

  return jsonResponse(_scheduleResponse(schedule), statusCode: 201);
}

Map<String, dynamic> _scheduleResponse(ScheduleSchema schedule) => {
      'schedule': schedule.toJson(includeBus: false),
      'bus_info': {
        'bus_number': schedule.busNumber ?? '',
        'total_seats': schedule.totalSeats ?? 0,
      },
    };

int? _intFrom(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleFrom(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _dateTimeFrom(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
