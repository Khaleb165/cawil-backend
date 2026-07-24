import 'dart:typed_data';

import 'package:postgres/postgres.dart';

String dbString(Object? value, String fieldName) {
  if (value is String) return value;
  if (value is UndecodedBytes) return value.asString;
  throw StateError(
    'Expected $fieldName to be a String, got ${value.runtimeType}',
  );
}

String? dbNullableString(Object? value, String fieldName) {
  if (value == null) return null;
  return dbString(value, fieldName);
}

double dbDouble(Object? value, String fieldName) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw StateError(
    'Expected $fieldName to be a number, got ${value.runtimeType}',
  );
}

double? dbNullableDouble(Object? value, String fieldName) {
  if (value == null) return null;
  return dbDouble(value, fieldName);
}

List<String> dbCommaSeparatedStrings(Object? value, String fieldName) {
  if (value == null) return const [];
  final raw = dbString(value, fieldName);
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> dbBytes(Object? value, String fieldName) {
  if (value == null) return const [];
  if (value is Uint8List) return value.toList(growable: false);
  if (value is List<int>) return List<int>.from(value, growable: false);
  if (value is UndecodedBytes) {
    return value.bytes.toList(growable: false);
  }
  throw StateError(
    'Expected $fieldName to be bytes, got ${value.runtimeType}',
  );
}

class UserSchema {
  final int id;
  final String? uid;
  final String email;
  final String passwordHash;
  final String username;
  final String avatarUrl;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSchema({
    required this.id,
    required this.uid,
    required this.email,
    required this.passwordHash,
    required this.username,
    required this.avatarUrl,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSchema.fromRow(List<Object?> row) => UserSchema(
        id: (row[0] as num).toInt(),
        uid: dbNullableString(row[1], 'users.uid'),
        email: dbString(row[2], 'users.email'),
        passwordHash: dbString(row[3], 'users.password_hash'),
        username: dbString(row[4], 'users.username'),
        avatarUrl: dbString(row[5], 'users.avatar_url'),
        role: dbString(row[6], 'users.role'),
        createdAt: (row[7] as DateTime).toUtc(),
        updatedAt: (row[8] as DateTime).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'email': email,
        'username': username,
        'avatar_url': avatarUrl,
        'role': role,
      };
}

class BusSchema {
  final int id;
  final String busNumber;
  final String? plateNumber;
  final int totalSeats;
  final String routeType;
  final String status;
  final DateTime createdAt;

  const BusSchema({
    required this.id,
    required this.busNumber,
    this.plateNumber,
    required this.totalSeats,
    required this.routeType,
    required this.status,
    required this.createdAt,
  });

  factory BusSchema.fromRow(List<Object?> row) => BusSchema(
        id: (row[0] as num).toInt(),
        busNumber: dbString(row[1], 'buses.bus_number'),
        plateNumber: dbNullableString(row[2], 'buses.plate_number'),
        totalSeats: (row[3] as num).toInt(),
        routeType: dbString(row[4], 'buses.route_type'),
        status: dbString(row[5], 'buses.status'),
        createdAt: (row[6] as DateTime).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bus_number': busNumber,
        'plate_number': plateNumber,
        'total_seats': totalSeats,
        'route_type': routeType,
        'status': status,
      };
}

class RouteSchema {
  final int id;
  final String origin;
  final String destination;
  final double? durationHours;
  final double? basePrice;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RouteSchema({
    required this.id,
    required this.origin,
    required this.destination,
    this.durationHours,
    this.basePrice,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RouteSchema.fromRow(List<Object?> row) => RouteSchema(
        id: (row[0] as num).toInt(),
        origin: dbString(row[1], 'routes.origin'),
        destination: dbString(row[2], 'routes.destination'),
        durationHours: dbNullableDouble(row[3], 'routes.duration_hours'),
        basePrice: dbNullableDouble(row[4], 'routes.base_price'),
        status: dbString(row[5], 'routes.status'),
        createdAt: (row[6] as DateTime).toUtc(),
        updatedAt: (row[7] as DateTime).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin,
        'destination': destination,
        'duration_hours': durationHours,
        'base_price': basePrice,
        'status': status,
      };
}

class ScheduleSchema {
  final int id;
  final int busId;
  final int routeId;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final DateTime? reportTime;
  final double price;
  final int seatsRemaining;
  final String status;
  final String? busNumber;
  final int? totalSeats;
  final List<String> bookedSeats;

  const ScheduleSchema({
    required this.id,
    required this.busId,
    required this.routeId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    this.arrivalTime,
    this.reportTime,
    required this.price,
    required this.seatsRemaining,
    required this.status,
    this.busNumber,
    this.totalSeats,
    this.bookedSeats = const [],
  });

  factory ScheduleSchema.fromRowWithBus(List<Object?> row) => ScheduleSchema(
        id: (row[0] as num).toInt(),
        busId: (row[1] as num).toInt(),
        routeId: (row[2] as num).toInt(),
        origin: dbString(row[3], 'schedules.origin'),
        destination: dbString(row[4], 'schedules.destination'),
        departureTime: (row[5] as DateTime).toUtc(),
        arrivalTime: row[6] == null ? null : (row[6] as DateTime).toUtc(),
        reportTime: row[7] == null ? null : (row[7] as DateTime).toUtc(),
        price: dbDouble(row[8], 'schedules.price'),
        seatsRemaining: (row[9] as num).toInt(),
        status: dbString(row[10], 'schedules.status'),
        busNumber: dbNullableString(row[12], 'buses.bus_number'),
        totalSeats: row[13] == null ? null : (row[13] as num).toInt(),
        bookedSeats: dbCommaSeparatedStrings(row[14], 'bookings.seat_number'),
      );

  Map<String, dynamic> toJson({bool includeBus = true}) {
    final json = <String, dynamic>{
      'id': id,
      'bus_id': busId,
      'route_id': routeId,
      'origin': origin,
      'destination': destination,
      'departure_time': departureTime.toUtc().toIso8601String(),
      'arrival_time': arrivalTime?.toUtc().toIso8601String(),
      'report_time': reportTime?.toUtc().toIso8601String(),
      'price': price,
      'seats_remaining': seatsRemaining,
      'booked_seats': bookedSeats,
      'status': status,
    };
    if (includeBus) {
      json['bus'] = {'bus_number': busNumber, 'total_seats': totalSeats};
    }
    return json;
  }
}

class BookingSchema {
  final int id;
  final int userId;
  final int scheduleId;
  final List<String> seatNumbers;
  final String contactPerson;
  final String phone;
  final double totalPrice;
  final String bookingRef;
  final List<int> qrData;
  final String status;
  final String paymentStatus;
  final String? email;
  final String? busNumber;

  const BookingSchema({
    required this.id,
    required this.userId,
    required this.scheduleId,
    required this.seatNumbers,
    required this.contactPerson,
    required this.phone,
    required this.totalPrice,
    required this.bookingRef,
    this.qrData = const [],
    required this.status,
    required this.paymentStatus,
    this.email,
    this.busNumber,
  });

  factory BookingSchema.fromRowWithDetails(List<Object?> row) => BookingSchema(
        id: (row[0] as num).toInt(),
        userId: (row[1] as num).toInt(),
        scheduleId: (row[2] as num).toInt(),
        seatNumbers: dbCommaSeparatedStrings(row[17], 'bookings.seat_number'),
        contactPerson: dbString(row[4], 'bookings.contact_person'),
        phone: dbString(row[5], 'bookings.phone'),
        totalPrice: dbDouble(row[6], 'bookings.total_price'),
        bookingRef: dbString(row[7], 'bookings.booking_ref'),
        qrData: row[8] is List<int> ? row[8] as List<int> : <int>[],
        status: dbString(row[9], 'bookings.status'),
        paymentStatus: dbString(row[10], 'bookings.payment_status'),
        email: dbNullableString(row[12], 'users.email'),
        busNumber: dbNullableString(row[13], 'buses.bus_number'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'schedule_id': scheduleId,
        'seat_numbers': seatNumbers,
        'contact_person': contactPerson,
        'phone': phone,
        'total_price': totalPrice,
        'booking_ref': bookingRef,
        'status': status,
        'payment_status': paymentStatus,
      };
}

class PaymentSchema {
  final int id;
  final int userId;
  final String bookingRef;
  final String provider;
  final String providerReference;
  final double amount;
  final String currency;
  final String status;
  final String? authorizationUrl;
  final String? accessCode;
  final String? channel;
  final String? gatewayResponse;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentSchema({
    required this.id,
    required this.userId,
    required this.bookingRef,
    required this.provider,
    required this.providerReference,
    required this.amount,
    required this.currency,
    required this.status,
    this.authorizationUrl,
    this.accessCode,
    this.channel,
    this.gatewayResponse,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentSchema.fromRow(List<Object?> row) => PaymentSchema(
        id: (row[0] as num).toInt(),
        userId: (row[1] as num).toInt(),
        bookingRef: dbString(row[2], 'payments.booking_ref'),
        provider: dbString(row[3], 'payments.provider'),
        providerReference: dbString(row[4], 'payments.provider_reference'),
        amount: dbDouble(row[5], 'payments.amount'),
        currency: dbString(row[6], 'payments.currency'),
        status: dbString(row[7], 'payments.status'),
        authorizationUrl:
            dbNullableString(row[8], 'payments.authorization_url'),
        accessCode: dbNullableString(row[9], 'payments.access_code'),
        channel: dbNullableString(row[10], 'payments.channel'),
        gatewayResponse: dbNullableString(row[11], 'payments.gateway_response'),
        paidAt: row[12] == null ? null : (row[12] as DateTime).toUtc(),
        createdAt: (row[13] as DateTime).toUtc(),
        updatedAt: (row[14] as DateTime).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'booking_ref': bookingRef,
        'provider': provider,
        'provider_reference': providerReference,
        'amount': amount,
        'currency': currency,
        'status': status,
        'authorization_url': authorizationUrl,
        'access_code': accessCode,
        'channel': channel,
        'gateway_response': gatewayResponse,
        'paid_at': paidAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

class RefreshTokenSchema {
  final int id;
  final int userId;
  final String jti;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  const RefreshTokenSchema({
    required this.id,
    required this.userId,
    required this.jti,
    required this.expiresAt,
    this.revokedAt,
  });

  factory RefreshTokenSchema.fromRow(List<Object?> row) => RefreshTokenSchema(
        id: (row[0] as num).toInt(),
        userId: (row[1] as num).toInt(),
        jti: dbString(row[2], 'refresh_tokens.jti'),
        expiresAt: (row[3] as DateTime).toUtc(),
        revokedAt: row[4] == null ? null : (row[4] as DateTime).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'jti': jti,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };
}

class AdminLogSchema {
  final int id;
  final int adminId;
  final String action;
  final String targetType;
  final int? targetId;
  final DateTime timestamp;

  const AdminLogSchema({
    required this.id,
    required this.adminId,
    required this.action,
    required this.targetType,
    this.targetId,
    required this.timestamp,
  });

  factory AdminLogSchema.fromRow(List<Object?> row) => AdminLogSchema(
        id: (row[0] as num).toInt(),
        adminId: (row[1] as num).toInt(),
        action: dbString(row[2], 'admin_logs.action'),
        targetType: dbString(row[3], 'admin_logs.target_type'),
        targetId: row[4] == null ? null : (row[4] as num).toInt(),
        timestamp: (row[5] as DateTime).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'admin_id': adminId,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}
