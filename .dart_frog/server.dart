// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/index.dart' as index;
import '../routes/schedules/index.dart' as schedules_index;
import '../routes/schedules/[id].dart' as schedules_$id;
import '../routes/payments/index.dart' as payments_index;
import '../routes/payments/verify/index.dart' as payments_verify_index;
import '../routes/docs/spec.dart' as docs_spec;
import '../routes/docs/index.dart' as docs_index;
import '../routes/bookings/index.dart' as bookings_index;
import '../routes/bookings/[id]/ticket.pdf.dart' as bookings_$id_ticket_pdf;
import '../routes/bookings/[id]/index.dart' as bookings_$id_index;
import '../routes/auth/reset-password.dart' as auth_reset_password;
import '../routes/auth/register.dart' as auth_register;
import '../routes/auth/refresh.dart' as auth_refresh;
import '../routes/auth/me.dart' as auth_me;
import '../routes/auth/login.dart' as auth_login;
import '../routes/auth/forgot-password.dart' as auth_forgot_password;
import '../routes/auth/change-password.dart' as auth_change_password;
import '../routes/admin/schedules/index.dart' as admin_schedules_index;
import '../routes/admin/route-defs/index.dart' as admin_route_defs_index;
import '../routes/admin/route-defs/[id].dart' as admin_route_defs_$id;
import '../routes/admin/buses/index.dart' as admin_buses_index;
import '../routes/admin/buses/[id].dart' as admin_buses_$id;

import '../routes/_middleware.dart' as middleware;
import '../routes/admin/_middleware.dart' as admin_middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/', (context) => buildHandler()(context))
    ..mount('/schedules', (context) => buildSchedulesHandler()(context))
    ..mount('/payments', (context) => buildPaymentsHandler()(context))
    ..mount('/payments/verify', (context) => buildPaymentsVerifyHandler()(context))
    ..mount('/docs', (context) => buildDocsHandler()(context))
    ..mount('/bookings', (context) => buildBookingsHandler()(context))
    ..mount('/bookings/<id>', (context,id,) => buildBookings$idHandler(id,)(context))
    ..mount('/auth', (context) => buildAuthHandler()(context))
    ..mount('/admin/schedules', (context) => buildAdminSchedulesHandler()(context))
    ..mount('/admin/route-defs', (context) => buildAdminRouteDefsHandler()(context))
    ..mount('/admin/buses', (context) => buildAdminBusesHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildSchedulesHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => schedules_$id.onRequest(context,id,))..all('/', (context) => schedules_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildPaymentsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => payments_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildPaymentsVerifyHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => payments_verify_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildDocsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/spec', (context) => docs_spec.onRequest(context,))..all('/', (context) => docs_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildBookingsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => bookings_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildBookings$idHandler(String id,) {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/ticket.pdf', (context) => bookings_$id_ticket_pdf.onRequest(context,id,))..all('/', (context) => bookings_$id_index.onRequest(context,id,));
  return pipeline.addHandler(router);
}

Handler buildAuthHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/change-password', (context) => auth_change_password.onRequest(context,))..all('/forgot-password', (context) => auth_forgot_password.onRequest(context,))..all('/login', (context) => auth_login.onRequest(context,))..all('/me', (context) => auth_me.onRequest(context,))..all('/refresh', (context) => auth_refresh.onRequest(context,))..all('/register', (context) => auth_register.onRequest(context,))..all('/reset-password', (context) => auth_reset_password.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAdminSchedulesHandler() {
  final pipeline = const Pipeline().addMiddleware(admin_middleware.middleware);
  final router = Router()
    ..all('/', (context) => admin_schedules_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAdminRouteDefsHandler() {
  final pipeline = const Pipeline().addMiddleware(admin_middleware.middleware);
  final router = Router()
    ..all('/<id>', (context,id,) => admin_route_defs_$id.onRequest(context,id,))..all('/', (context) => admin_route_defs_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAdminBusesHandler() {
  final pipeline = const Pipeline().addMiddleware(admin_middleware.middleware);
  final router = Router()
    ..all('/<id>', (context,id,) => admin_buses_$id.onRequest(context,id,))..all('/', (context) => admin_buses_index.onRequest(context,));
  return pipeline.addHandler(router);
}

