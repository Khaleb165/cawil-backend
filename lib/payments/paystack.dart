import 'dart:convert';
import 'dart:io';

class PaystackClient {
  PaystackClient({
    String? secretKey,
    String? callbackUrl,
    String? currency,
  })  : _secretKey = secretKey ?? _readEnv('PAYSTACK_SECRET_KEY') ?? '',
        _callbackUrl = callbackUrl ?? _readEnv('PAYSTACK_CALLBACK_URL'),
        _currency =
            (currency ?? _readEnv('PAYSTACK_CURRENCY') ?? 'GHS').toUpperCase();

  static const _host = 'api.paystack.co';

  final String _secretKey;
  final String? _callbackUrl;
  final String _currency;

  String get currency => _currency;

  Future<Map<String, dynamic>> initializeTransaction({
    required String email,
    required double amount,
    required String reference,
    required String bookingRef,
    required List<String> seatNumbers,
    String? paymentMethod,
  }) async {
    _ensureConfigured();

    final body = <String, dynamic>{
      'email': email,
      'amount': (amount * 100).round().toString(),
      'currency': _currency,
      'reference': reference,
      'metadata': jsonEncode({
        'booking_ref': bookingRef,
        'seat_numbers': seatNumbers,
      }),
    };

    final callbackUrl = _callbackUrl;
    if (callbackUrl != null && callbackUrl.isNotEmpty) {
      body['callback_url'] = callbackUrl;
    }

    final channels = _channelsFor(paymentMethod);
    if (channels.isNotEmpty) {
      body['channels'] = channels;
    }

    final response = await _send(
      method: 'POST',
      path: '/transaction/initialize',
      body: body,
    );

    if (response['status'] != true) {
      throw StateError(response['message']?.toString() ??
          'Unable to initialize Paystack transaction');
    }

    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<Map<String, dynamic>> verifyTransaction(String reference) async {
    _ensureConfigured();
    final response = await _send(
      method: 'GET',
      path: '/transaction/verify/$reference',
    );

    if (response['status'] != true) {
      throw StateError(
        response['message']?.toString() ?? 'Unable to verify transaction',
      );
    }

    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.https(_host, path),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $_secretKey')
        ..set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType);

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(decoded['message']?.toString() ??
            'Paystack request failed with ${response.statusCode}');
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  void _ensureConfigured() {
    if (_secretKey.isEmpty) {
      throw StateError('PAYSTACK_SECRET_KEY is not configured');
    }
  }

  static List<String> _channelsFor(String? paymentMethod) {
    final normalized = paymentMethod?.toLowerCase().trim() ?? '';
    if (normalized.contains('wallet') ||
        normalized.contains('mobile') ||
        normalized.contains('momo')) {
      return const ['mobile_money'];
    }
    if (normalized.contains('master') ||
        normalized.contains('card') ||
        normalized.contains('visa')) {
      return const ['card'];
    }
    return const [];
  }

  static String? _readEnv(String key) {
    final value = Platform.environment[key];
    if (value != null && value.isNotEmpty) return value;

    try {
      final file = File('.env');
      if (!file.existsSync()) return null;
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eq = trimmed.indexOf('=');
        if (eq == -1) continue;
        if (trimmed.substring(0, eq).trim() == key) {
          return trimmed.substring(eq + 1).trim();
        }
      }
    } catch (_) {}

    return null;
  }
}
