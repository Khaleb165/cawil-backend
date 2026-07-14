import 'dart:io';
import 'dart:math';
import 'package:postgres/postgres.dart';
import 'schemas.dart';
export 'schemas.dart';

class CaWilDatabase {
  static CaWilDatabase? _instance;
  static Future<void>? _initFuture;

  static bool get isInitialized => _instance != null;

  static CaWilDatabase get instance {
    if (_instance == null) {
      throw StateError(
        'Database not initialized. Call CaWilDatabase.initialize() first.',
      );
    }
    return _instance!;
  }

  static Future<void> ensureInitialized() async {
    if (_instance != null) return;
    if (_initFuture != null) return _initFuture;
    _initFuture = initialize();
    await _initFuture;
  }

  static Future<CaWilDatabase> initialize({String? dbUrl}) async {
    final url = dbUrl ??
        Platform.environment['DB_URL'] ??
        _readDotEnv('DB_URL') ??
        'postgresql://user:pass@localhost:5432/cawil';
    print('Connecting to database at $url');
    final db = CaWilDatabase._(url);
    try {
      await db.connect();
    } catch (e) {
      print('Database connection failed: $e');
      rethrow;
    }
    _instance = db;
    return db;
  }

  static String? _readDotEnv(String key) {
    try {
      final file = File('.env');
      if (!file.existsSync()) return null;
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eq = trimmed.indexOf('=');
        if (eq == -1) continue;
        final k = trimmed.substring(0, eq).trim();
        if (k == key) {
          return trimmed.substring(eq + 1).trim();
        }
      }
    } catch (_) {}
    return null;
  }

  late Connection _conn;
  final String _url;

  CaWilDatabase._(this._url);

  Future<void> connect() async {
    print('Connecting to database...');
    _conn = await Connection.openFromUrl(_url);
    print('Database connected successfully');
    await runMigrations();
  }

  Future<void> runMigrations() async {
    final schemaFile = File('database/schema.sql');
    if (!schemaFile.existsSync()) {
      print('No schema.sql found, skipping migrations');
      return;
    }

    final statements = _splitSqlStatements(schemaFile.readAsStringSync())
        .where(_hasExecutableSql);

    for (final stmt in statements) {
      await _conn.execute(stmt);
    }
    print('Schema migrations applied');
  }

  Future<void> close() async {
    if (_conn.isOpen) {
      await _conn.close();
    }
  }

  bool get isConnected => _conn.isOpen;

  Future<List<Object?>?> queryOne(String sql, [List<Object?>? params]) async {
    final result = await _conn.execute(sql, parameters: params ?? const []);
    if (result.isEmpty) {
      return null;
    }
    return result.first;
  }

  Future<List<List<Object?>>> query(String sql, [List<Object?>? params]) async {
    final result = await _conn.execute(sql, parameters: params ?? const []);
    return result.toList();
  }

  Future<bool> isAdmin(int userId) async {
    final row = await queryOne(
      'SELECT role FROM users WHERE id = \$1',
      [userId],
    );
    if (row == null) return false;
    return dbString(row[0], 'users.role') == 'admin';
  }
}

Iterable<String> _splitSqlStatements(String sql) sync* {
  final buffer = StringBuffer();
  String? dollarQuoteTag;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;

  for (var i = 0; i < sql.length; i++) {
    final char = sql[i];
    final next = i + 1 < sql.length ? sql[i + 1] : '';

    if (inLineComment) {
      buffer.write(char);
      if (char == '\n') inLineComment = false;
      continue;
    }

    if (inBlockComment) {
      buffer.write(char);
      if (char == '*' && next == '/') {
        buffer.write(next);
        i++;
        inBlockComment = false;
      }
      continue;
    }

    if (dollarQuoteTag != null) {
      if (sql.startsWith(dollarQuoteTag, i)) {
        buffer.write(dollarQuoteTag);
        i += dollarQuoteTag.length - 1;
        dollarQuoteTag = null;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && char == '-' && next == '-') {
      buffer.write(char);
      buffer.write(next);
      i++;
      inLineComment = true;
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && char == '/' && next == '*') {
      buffer.write(char);
      buffer.write(next);
      i++;
      inBlockComment = true;
      continue;
    }

    if (inSingleQuote && char == "'" && next == "'") {
      buffer.write(char);
      buffer.write(next);
      i++;
      continue;
    }

    if (!inDoubleQuote && char == "'") {
      inSingleQuote = !inSingleQuote;
      buffer.write(char);
      continue;
    }

    if (inDoubleQuote && char == '"' && next == '"') {
      buffer.write(char);
      buffer.write(next);
      i++;
      continue;
    }

    if (!inSingleQuote && char == '"') {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && char == r'$') {
      final match = RegExp(r'^\$[A-Za-z_][A-Za-z0-9_]*?\$|^\$\$')
          .firstMatch(sql.substring(i));
      if (match != null) {
        dollarQuoteTag = match.group(0);
        buffer.write(dollarQuoteTag);
        i += dollarQuoteTag!.length - 1;
        continue;
      }
    }

    if (!inSingleQuote && !inDoubleQuote && char == ';') {
      final statement = buffer.toString().trim();
      if (statement.isNotEmpty) yield statement;
      buffer.clear();
      continue;
    }

    buffer.write(char);
  }

  final statement = buffer.toString().trim();
  if (statement.isNotEmpty) yield statement;
}

bool _hasExecutableSql(String statement) {
  final withoutLineComments = statement.replaceAll(RegExp(r'--[^\r\n]*'), '');
  final withoutBlockComments = withoutLineComments.replaceAll(
    RegExp(r'/\*[\s\S]*?\*/'),
    '',
  );
  return withoutBlockComments.trim().isNotEmpty;
}

String _validateEmail(String email) {
  final trimmed = email.trim().toLowerCase();
  if (!RegExp(r'^[\w\.\+-]+@[\w-]+\.[\w\.]+$').hasMatch(trimmed)) {
    throw ArgumentError('Invalid email format');
  }
  return trimmed;
}

String _cleanUsername(String username) {
  final cleaned = username.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  if (cleaned.isEmpty || cleaned.length > 30) {
    throw ArgumentError(
        'Username must be 1-30 alphanumeric/underscore characters');
  }
  return cleaned;
}

String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return value.substring(0, maxLength);
}

String _truncateTrimmed(String value, int maxLength) {
  return _truncate(value.trim(), maxLength);
}

int _clampInt(int value, int minVal, int maxVal) {
  if (value < minVal) return minVal;
  if (value > maxVal) return maxVal;
  return value;
}

List<double> _splitPrice(double totalPrice, int parts) {
  final totalCents = (totalPrice * 100).round();
  final baseCents = totalCents ~/ parts;
  var remainder = totalCents % parts;
  return List<double>.generate(parts, (_) {
    final cents = baseCents + (remainder > 0 ? 1 : 0);
    if (remainder > 0) remainder--;
    return cents / 100;
  }, growable: false);
}

// ====================================================================
// USERS
// ====================================================================

Future<UserSchema?> userByEmail(CaWilDatabase db, String email) async {
  final row = await db.queryOne(
    'SELECT id, uid, email, password_hash, username, avatar_url, role, created_at, updated_at FROM users WHERE email = \$1',
    [email.trim().toLowerCase()],
  );
  if (row == null) return null;
  return UserSchema.fromRow(row);
}

Future<UserSchema?> userById(CaWilDatabase db, int id) async {
  final row = await db.queryOne(
    'SELECT id, uid, email, password_hash, username, avatar_url, role, created_at, updated_at FROM users WHERE id = \$1',
    [id],
  );
  if (row == null) return null;
  return UserSchema.fromRow(row);
}

Future<UserSchema> registerUser(
  CaWilDatabase db, {
  required String email,
  required String passwordHash,
  required String username,
  String? uid,
  String avatarUrl = '',
  String role = 'user',
}) async {
  final safeEmail = _validateEmail(email);
  final cleanUsername = _cleanUsername(username);

  await db.query(
    'INSERT INTO users (uid, email, password_hash, username, avatar_url, role) VALUES (\$1, \$2, \$3, \$4, \$5, \$6)',
    [uid, safeEmail, passwordHash, cleanUsername, avatarUrl, role],
  );

  final user = await userByEmail(db, safeEmail);
  if (user == null) throw Exception('User creation failed');
  return user;
}

Future<void> updatePassword(
    CaWilDatabase db, int userId, String newHash) async {
  await db.query(
    'UPDATE users SET password_hash = \$1, updated_at = now() WHERE id = \$2',
    [newHash, userId],
  );
}

Future<void> updateUser(
  CaWilDatabase db,
  int userId, {
  String? username,
  String? avatarUrl,
}) async {
  final parts = <String>[];
  final params = <Object>[userId];
  var idx = 1;

  if (username != null && username.trim().isNotEmpty) {
    parts.add('username = \$$idx');
    params.add(_cleanUsername(username));
    idx++;
  }

  if (avatarUrl != null) {
    parts.add('avatar_url = \$$idx');
    params.add(avatarUrl);
    idx++;
  }

  if (parts.isEmpty) return;

  parts.add('updated_at = now()');
  await db.query(
    'UPDATE users SET ${parts.join(', ')} WHERE id = \$1',
    params,
  );
}

// ====================================================================
// BUSES
// ====================================================================

Future<List<BusSchema>> listBuses(CaWilDatabase db) async {
  final rows = await db.query(
    'SELECT id, bus_number, plate_number, total_seats, route_type, status, created_at FROM buses ORDER BY id',
  );
  return rows.map((row) => BusSchema.fromRow(row)).toList();
}

Future<BusSchema?> getBusById(CaWilDatabase db, int id) async {
  final row = await db.queryOne(
    'SELECT id, bus_number, plate_number, total_seats, route_type, status, created_at FROM buses WHERE id = \$1',
    [id],
  );
  if (row == null) return null;
  return BusSchema.fromRow(row);
}

Future<BusSchema> createBus(
  CaWilDatabase db, {
  required String busNumber,
  String? plateNumber,
  int totalSeats = 32,
  String routeType = 'long-distance',
}) async {
  final clampedSeats = _clampInt(totalSeats, 18, 64);
  final safeType = (routeType == 'local') ? 'local' : 'long-distance';
  final trimmedNumber = _truncateTrimmed(busNumber, 20);

  final row = await db.queryOne(
    'INSERT INTO buses (bus_number, plate_number, total_seats, route_type) VALUES (\$1, \$2, \$3, \$4) RETURNING id, bus_number, plate_number, total_seats, route_type, status, created_at',
    [trimmedNumber, plateNumber ?? '', clampedSeats, safeType],
  );

  if (row == null) throw StateError('Failed to create bus');
  return BusSchema.fromRow(row);
}

Future<BusSchema> updateBus(
  CaWilDatabase db,
  int id, {
  String? busNumber,
  String? plateNumber,
  int? totalSeats,
  String? status,
}) async {
  final current = await getBusById(db, id);
  if (current == null) throw ArgumentError('Bus not found');

  final parts = <String>[];
  final params = <Object>[id];
  var idx = 1;

  if (busNumber != null && busNumber.trim().isNotEmpty) {
    parts.add('bus_number = \$$idx');
    params.add(_truncateTrimmed(busNumber, 20));
    idx++;
  }

  if (plateNumber != null) {
    parts.add('plate_number = \$$idx');
    params.add(plateNumber);
    idx++;
  }

  if (totalSeats != null) {
    parts.add('total_seats = \$$idx');
    params.add(_clampInt(totalSeats, 18, 64));
    idx++;
  }

  if (status != null && ['active', 'inactive'].contains(status)) {
    parts.add('status = \$$idx');
    params.add(status);
    idx++;
  }

  if (parts.isEmpty) return current;

  await db.query(
    'UPDATE buses SET ${parts.join(', ')} WHERE id = \$1',
    params,
  );

  final updated = await getBusById(db, id);
  return updated!;
}

Future<void> deleteBus(CaWilDatabase db, int id) async {
  await db.query('DELETE FROM buses WHERE id = \$1', [id]);
}

// ====================================================================
// ROUTES
// ====================================================================

Future<List<RouteSchema>> listRoutes(CaWilDatabase db) async {
  final rows = await db.query(
    'SELECT id, origin, destination, duration_hours, base_price, status, created_at, updated_at FROM routes ORDER BY id',
  );
  return rows.map((row) => RouteSchema.fromRow(row)).toList();
}

Future<RouteSchema?> getRouteById(CaWilDatabase db, int id) async {
  final row = await db.queryOne(
    'SELECT id, origin, destination, duration_hours, base_price, status, created_at, updated_at FROM routes WHERE id = \$1',
    [id],
  );
  if (row == null) return null;
  return RouteSchema.fromRow(row);
}

Future<RouteSchema> createRoute(
  CaWilDatabase db, {
  required String origin,
  required String destination,
  double? durationHours,
  double? basePrice,
}) async {
  final safeOrigin = _truncateTrimmed(origin, 80);
  final safeDest = _truncateTrimmed(destination, 80);

  final row = await db.queryOne(
    "INSERT INTO routes (origin, destination, duration_hours, base_price, status) VALUES (\$1, \$2, \$3, \$4, 'active') RETURNING id, origin, destination, duration_hours, base_price, status, created_at, updated_at",
    [safeOrigin, safeDest, durationHours ?? 0, basePrice ?? 0],
  );

  if (row == null) throw StateError('Failed to create route');
  return RouteSchema.fromRow(row);
}

Future<RouteSchema> updateRoute(
  CaWilDatabase db,
  int id, {
  String? origin,
  String? destination,
  double? durationHours,
  double? basePrice,
  String? status,
}) async {
  final current = await getRouteById(db, id);
  if (current == null) throw ArgumentError('Route not found');

  final parts = <String>[];
  final params = <Object>[id];
  var idx = 1;

  if (origin != null &&
      origin.trim().isNotEmpty &&
      origin.trim() != current.origin) {
    final safe = _truncateTrimmed(origin, 80);
    parts.add('origin = \$$idx');
    params.add(safe);
    idx++;
  }

  if (destination != null &&
      destination.trim().isNotEmpty &&
      destination.trim() != current.destination) {
    final safe = _truncateTrimmed(destination, 80);
    parts.add('destination = \$$idx');
    params.add(safe);
    idx++;
  }

  if (durationHours != null && durationHours > 0) {
    parts.add('duration_hours = \$$idx');
    params.add(durationHours.clamp(0.1, 23.99));
    idx++;
  }

  if (basePrice != null && basePrice >= 0) {
    parts.add('base_price = \$$idx');
    params.add(basePrice);
    idx++;
  }

  if (status != null && ['active', 'inactive'].contains(status)) {
    parts.add('status = \$$idx');
    params.add(status);
    idx++;
  }

  if (parts.isEmpty) return current;

  parts.add('updated_at = now()');

  await db.query(
    'UPDATE routes SET ${parts.join(', ')} WHERE id = \$1',
    params,
  );

  final updated = await getRouteById(db, id);
  return updated!;
}

Future<void> deleteRoute(CaWilDatabase db, int id) async {
  await db.query('DELETE FROM routes WHERE id = \$1', [id]);
}

// ====================================================================
// SCHEDULES
// ====================================================================

Future<List<ScheduleSchema>> searchSchedules(
  CaWilDatabase db, {
  String? origin,
  String? destination,
  DateTime? date,
  int? busId,
}) async {
  var sql = 'SELECT s.id, s.bus_id, s.route_id, s.origin, s.destination, '
      's.departure_time, s.arrival_time, s.report_time, s.price, '
      's.seats_remaining, s.status, s.created_at, '
      'b.bus_number, b.total_seats, '
      "COALESCE((SELECT string_agg(bk.seat_number, ',' ORDER BY bk.seat_number) "
      'FROM bookings bk '
      "WHERE bk.schedule_id = s.id AND bk.status = 'confirmed'), '') "
      'FROM schedules s '
      'JOIN buses b ON s.bus_id = b.id '
      "WHERE s.status = 'active' ";

  var params = <Object>[];
  var pIdx = 1;

  if (origin != null && origin.trim().isNotEmpty) {
    sql += 'AND LOWER(s.origin) LIKE LOWER(\$' + pIdx.toString() + ') ';
    params.add('%${origin.trim().toLowerCase()}%');
    pIdx++;
  }

  if (destination != null && destination.trim().isNotEmpty) {
    sql += 'AND LOWER(s.destination) LIKE LOWER(\$' + pIdx.toString() + ') ';
    params.add('%${destination.trim().toLowerCase()}%');
    pIdx++;
  }

  if (date != null) {
    sql += 'AND DATE(s.departure_time) = \$' + pIdx.toString() + ' ';
    params.add(date.toUtc().toIso8601String().split('T')[0]);
    pIdx++;
  }

  if (busId != null && busId > 0) {
    sql += 'AND s.bus_id = \$' + pIdx.toString() + ' ';
    params.add(busId);
    pIdx++;
  }

  sql += 'ORDER BY s.departure_time ASC';

  final rows = await db.query(sql, params);
  return rows.map((row) => ScheduleSchema.fromRowWithBus(row)).toList();
}

Future<ScheduleSchema> createSchedule(
  CaWilDatabase db, {
  required int busId,
  required int routeId,
  required DateTime departureTime,
  DateTime? arrivalTime,
  double? price,
  int? seatsRemaining,
}) async {
  final bus = await getBusById(db, busId);
  if (bus == null) {
    throw ArgumentError('Bus not found');
  }

  final route = await getRouteById(db, routeId);
  if (route == null) {
    throw ArgumentError('Route not found');
  }

  final schedulePrice = price ?? route.basePrice ?? 0;
  final remainingSeats = _clampInt(seatsRemaining ?? bus.totalSeats, 0, 64);

  final row = await db.queryOne(
    'INSERT INTO schedules (bus_id, route_id, origin, destination, '
    'departure_time, arrival_time, price, seats_remaining, status) '
    "VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, 'active') "
    'RETURNING id, bus_id, route_id, origin, destination, departure_time, '
    'arrival_time, report_time, price, seats_remaining, status, created_at, '
    '(SELECT bus_number FROM buses WHERE id = \$1), '
    "(SELECT total_seats FROM buses WHERE id = \$1), ''",
    [
      busId,
      routeId,
      route.origin,
      route.destination,
      departureTime.toUtc(),
      arrivalTime?.toUtc(),
      schedulePrice,
      remainingSeats,
    ],
  );

  if (row == null) throw StateError('Failed to create schedule');
  return ScheduleSchema.fromRowWithBus(row);
}

Future<ScheduleSchema?> getScheduleById(CaWilDatabase db, int id) async {
  final row = await db.queryOne(
    'SELECT s.id, s.bus_id, s.route_id, s.origin, s.destination, '
    's.departure_time, s.arrival_time, s.report_time, s.price, '
    's.seats_remaining, s.status, s.created_at, b.bus_number, b.total_seats, '
    "COALESCE((SELECT string_agg(bk.seat_number, ',' ORDER BY bk.seat_number) "
    'FROM bookings bk '
    "WHERE bk.schedule_id = s.id AND bk.status = 'confirmed'), '') "
    'FROM schedules s JOIN buses b ON s.bus_id = b.id WHERE s.id = \$1',
    [id],
  );
  if (row == null) return null;
  return ScheduleSchema.fromRowWithBus(row);
}

Future<int> updateScheduleSeats(
    CaWilDatabase db, int scheduleId, int newRemaining) async {
  final clamped = _clampInt(newRemaining, 0, 64);
  await db.query(
    'UPDATE schedules SET seats_remaining = \$1 WHERE id = \$2',
    [clamped, scheduleId],
  );
  return clamped;
}

// ====================================================================
// BOOKINGS
// ====================================================================

Future<Map<String, dynamic>> createBooking(
  CaWilDatabase db, {
  required int userId,
  required int scheduleId,
  required List<String> seatNumbers,
  required String contactPerson,
  required String phone,
  required double totalPrice,
}) async {
  if (seatNumbers.isEmpty) {
    throw ArgumentError('At least one seat number is required');
  }

  final cleanedSeatNumbers =
      seatNumbers.map((seat) => seat.trim()).toList(growable: false);

  if (cleanedSeatNumbers.any((seat) => seat.isEmpty || seat.length > 4)) {
    throw ArgumentError('Seat numbers must be 1-4 characters');
  }

  final uniqueSeatNumbers = cleanedSeatNumbers.toSet().toList(growable: false);

  if (uniqueSeatNumbers.length != cleanedSeatNumbers.length) {
    throw ArgumentError('Seat numbers must be unique');
  }

  final safeContactPerson = _truncateTrimmed(contactPerson, 100);
  final safePhone = _truncateTrimmed(phone, 20);
  final bookingRef = generateBookingRef();
  final insertedIds = <int>[];
  final seatPrices = _splitPrice(totalPrice, uniqueSeatNumbers.length);

  await db.query('BEGIN');
  try {
    final avail = await db.queryOne(
      'SELECT seats_remaining FROM schedules WHERE id = \$1 FOR UPDATE',
      [scheduleId],
    );

    if (avail == null) throw ArgumentError('Schedule not found');

    final currentSeats = (avail[0] as num).toInt();
    if (currentSeats <= 0 || currentSeats < uniqueSeatNumbers.length) {
      throw StateError('No seats available for this schedule');
    }

    for (final seatNumber in uniqueSeatNumbers) {
      final existingSeat = await db.queryOne(
        "SELECT id FROM bookings WHERE schedule_id = \$1 AND seat_number = \$2 AND status = 'confirmed'",
        [scheduleId, seatNumber],
      );
      if (existingSeat != null) {
        throw StateError('Seat already booked: $seatNumber');
      }
    }

    for (var i = 0; i < uniqueSeatNumbers.length; i++) {
      final insertRow = await db.queryOne(
        "INSERT INTO bookings (user_id, schedule_id, seat_number, contact_person, phone, total_price, booking_ref, status, payment_status) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, 'confirmed', 'pending') RETURNING id",
        [
          userId,
          scheduleId,
          uniqueSeatNumbers[i],
          safeContactPerson,
          safePhone,
          seatPrices[i],
          bookingRef,
        ],
      );
      insertedIds.add(insertRow![0] as int);
    }

    await db.query(
      'UPDATE schedules SET seats_remaining = \$1 WHERE id = \$2',
      [currentSeats - uniqueSeatNumbers.length, scheduleId],
    );

    await db.query('COMMIT');
  } catch (_) {
    await db.query('ROLLBACK');
    rethrow;
  }

  return {
    'id': insertedIds.first,
    'ids': insertedIds,
    'booking_ref': bookingRef,
    'seat_numbers': uniqueSeatNumbers,
    'contact_person': safeContactPerson,
    'total_price': totalPrice,
  };
}

Future<BookingSchema?> getBookingById(CaWilDatabase db, int id) async {
  final row = await db.queryOne(
    'SELECT b.id, b.user_id, b.schedule_id, b.seat_number, b.contact_person, '
    'b.phone, '
    '(SELECT COALESCE(SUM(b2.total_price), 0) FROM bookings b2 '
    'WHERE b2.booking_ref = b.booking_ref AND b2.status = b.status), '
    'b.booking_ref, b.qr_data, b.status, b.payment_status, '
    'b.created_at, u.email, bs.bus_number, s.departure_time, s.origin, s.destination '
    ", COALESCE((SELECT string_agg(b2.seat_number, ',' ORDER BY b2.seat_number) "
    'FROM bookings b2 '
    'WHERE b2.booking_ref = b.booking_ref AND b2.status = b.status), b.seat_number) '
    'FROM bookings b '
    'JOIN users u ON b.user_id = u.id '
    'JOIN schedules s ON b.schedule_id = s.id '
    'JOIN buses bs ON s.bus_id = bs.id '
    'WHERE b.id = \$1',
    [id],
  );
  if (row == null) return null;
  return BookingSchema.fromRowWithDetails(row);
}

Future<bool> cancelBooking(CaWilDatabase db, int bookingId, int userId,
    {bool isAdmin = false}) async {
  final row = await db.queryOne(
    'SELECT schedule_id, user_id, booking_ref FROM bookings WHERE id = \$1',
    [bookingId],
  );

  if (row == null) throw ArgumentError('Booking not found');

  final scheduleId = row[0] as int;
  final ownerId = row[1] as int;
  final bookingRef = dbString(row[2], 'bookings.booking_ref');
  if (!isAdmin && ownerId != userId) {
    throw StateError('Only owner or admin can cancel this booking');
  }

  final confirmedRows = await db.queryOne(
    "SELECT COUNT(*) FROM bookings WHERE booking_ref = \$1 AND status = 'confirmed'",
    [bookingRef],
  );
  final confirmedSeatCount = (confirmedRows?[0] as num?)?.toInt() ?? 0;

  await db.query(
    "UPDATE bookings SET status = 'cancelled' WHERE booking_ref = \$1 AND status = 'confirmed'",
    [bookingRef],
  );

  if (confirmedSeatCount > 0) {
    await db.query(
      "UPDATE schedules SET seats_remaining = LEAST(seats_remaining + \$1, 64) WHERE id = \$2 AND status = 'active'",
      [confirmedSeatCount, scheduleId],
    );
  }

  return true;
}

Future<List<int>?> getBookingPdf(CaWilDatabase db, int bookingId) async {
  final row = await db.queryOne(
    'SELECT qr_data FROM bookings WHERE id = \$1',
    [bookingId],
  );
  return row == null ? null : row[0] as List<int>;
}

Future<void> updateBookingPdf(
    CaWilDatabase db, int bookingId, List<int> pdfBytes) async {
  await db.query(
    'UPDATE bookings SET qr_data = \$1 WHERE id = \$2',
    [pdfBytes, bookingId],
  );
}

// ====================================================================
// REFRESH TOKENS
// ====================================================================

Future<void> createRefreshToken(
    CaWilDatabase db, int userId, String jti, DateTime expiresAt) async {
  await db.query(
    'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = \$1 AND revoked_at IS NULL',
    [userId],
  );

  await db.query(
    'INSERT INTO refresh_tokens (user_id, jti, expires_at) VALUES (\$1, \$2, \$3)',
    [userId, jti, expiresAt.toUtc()],
  );
}

Future<RefreshTokenSchema?> getValidRefreshToken(
    CaWilDatabase db, String jti) async {
  final row = await db.queryOne(
    'SELECT id, user_id, jti, expires_at, revoked_at FROM refresh_tokens WHERE jti = \$1 AND revoked_at IS NULL',
    [jti],
  );

  if (row == null) return null;

  final expiresAt = row[3] as DateTime;
  if (expiresAt.isBefore(DateTime.now())) {
    await revokeRefreshToken(db, jti);
    return null;
  }

  return RefreshTokenSchema.fromRow(row);
}

Future<void> revokeRefreshToken(CaWilDatabase db, String jti) async {
  await db.query(
    'UPDATE refresh_tokens SET revoked_at = now() WHERE jti = \$1 AND revoked_at IS NULL',
    [jti],
  );
}

// ====================================================================
// ADMIN LOGS
// ====================================================================

Future<void> createAdminLog(
  CaWilDatabase db,
  int adminId,
  String action, {
  String? targetType,
  int? targetId,
}) async {
  await db.query(
    'INSERT INTO admin_logs (admin_id, action, target_type, target_id) VALUES (\$1, \$2, \$3, \$4)',
    [adminId, action, targetType ?? '', targetId ?? 0],
  );
}

// ====================================================================
// UTILITIES
// ====================================================================

String generateBookingRef() {
  final now = DateTime.now();
  final yy = (now.year % 100).toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');

  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  final suffix = List.generate(
    6,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
  return 'CAW-$yy$mm$dd-$suffix';
}
