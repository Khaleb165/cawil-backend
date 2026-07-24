import 'package:dart_frog/dart_frog.dart';
import 'package:cawil_backend/db/database.dart';

Handler middleware(Handler handler) {
  return (context) async {
    await CaWilDatabase.ensureInitialized();

    if (context.request.method == HttpMethod.options) {
      return Response(
        statusCode: 204,
        headers: _corsHeaders,
      );
    }

    final response = await handler(context);
    return Response.stream(
      statusCode: response.statusCode,
      body: response.bytes(),
      headers: {
        ...response.headers,
        ..._corsHeaders,
      },
    );
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS, PATCH',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
