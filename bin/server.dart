import 'package:dart_frog/dart_frog.dart';
import 'dart:io';
import 'package:cawil_backend/db/database.dart';

Future<HttpServer> run(Handler handler, InternetAddress host, int port) async {
  await CaWilDatabase.initialize();
  print('Database connected');
  final server = await serve(handler, host, port);
  print('Server running at http://${host.address}:$port');
  return server;
}
