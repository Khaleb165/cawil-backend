import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  final serverHost = context.request.uri.host;
  final serverPort = context.request.uri.port;
  final baseUrl = serverHost.isNotEmpty
      ? 'http://$serverHost:$serverPort'
      : 'http://localhost:8080';

  final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>CaWil API Documentation</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <style>
    html { box-sizing: border-box; overflow-y: scroll; }
    *, *::before, *::after { box-sizing: inherit; }
    body { margin: 0; background: #fafafa; }
    .topbar { display: none; }
    .information-container.wrapper { padding-top: 10px; }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js" crossorigin></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: '$baseUrl/docs/spec',
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
        ],
        defaultModelsExpandDepth: 1,
        docExpansion: "list",
        filter: true,
      });
    };
  </script>
</body>
</html>
''';

  return Response(
    body: html,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
    },
  );
}
