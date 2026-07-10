import 'package:dart_frog/dart_frog.dart';
import 'package:cawil_backend/db/database.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return jsonError(405, 'Method not allowed');
  }

  try {
    final uri = context.request.uri;
    final queryParams = uri.queryParameters;

    final origin = queryParams['origin'];
    final destination = queryParams['destination'];
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
      origin: origin,
      destination: destination,
      date: date,
      busId: busId,
    );

    final result = schedules.map((s) => {
          'schedule': s.toJson(includeBus: false),
          'bus_info': {
            'bus_number': s.busNumber ?? '',
            'total_seats': s.totalSeats ?? 0,
          },
        }).toList();

    return jsonResponse(result);
  } catch (e) {
    return jsonError(400, e.toString());
  }
}
