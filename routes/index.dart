import 'package:dart_frog/dart_frog.dart';
import 'package:cawil_backend/middleware/response.dart';

Future<Response> onRequest(RequestContext context) async {
  return jsonResponse({
    'status': 'ok',
    'service': 'cawil_backend',
    'version': '1.0.0',
  });
}
