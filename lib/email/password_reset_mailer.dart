import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class PasswordResetMailer {
  PasswordResetMailer({
    String? host,
    int? port,
    String? username,
    String? password,
    String? fromEmail,
    String? fromName,
    bool? ssl,
    bool? allowInsecure,
    String? resetUrl,
  })  : _host = host ?? _readEnv('SMTP_HOST') ?? '',
        _port = port ?? int.tryParse(_readEnv('SMTP_PORT') ?? '') ?? 587,
        _username = username ?? _readEnv('SMTP_USERNAME'),
        _password = password ?? _readEnv('SMTP_PASSWORD'),
        _fromEmail = fromEmail ?? _readEnv('SMTP_FROM_EMAIL') ?? '',
        _fromName = fromName ?? _readEnv('SMTP_FROM_NAME') ?? 'CaWil',
        _ssl = ssl ?? _readBoolEnv('SMTP_SSL', defaultValue: false),
        _allowInsecure = allowInsecure ?? _readBoolEnv('SMTP_ALLOW_INSECURE'),
        _resetUrl = resetUrl ?? _readEnv('PASSWORD_RESET_URL');

  final String _host;
  final int _port;
  final String? _username;
  final String? _password;
  final String _fromEmail;
  final String _fromName;
  final bool _ssl;
  final bool _allowInsecure;
  final String? _resetUrl;

  Future<void> sendPasswordResetEmail({
    required String toEmail,
    required String username,
    required String token,
  }) async {
    _validateConfig();

    final message = Message()
      ..from = Address(_fromEmail, _fromName)
      ..recipients.add(toEmail)
      ..subject = 'Reset your CaWil password'
      ..text = _plainText(username: username, token: token)
      ..html = _html(username: username, token: token);

    final smtpServer = SmtpServer(
      _host,
      port: _port,
      username: _username,
      password: _password,
      ssl: _ssl,
      allowInsecure: _allowInsecure,
    );

    await send(message, smtpServer);
  }

  void _validateConfig() {
    if (_host.isEmpty) {
      throw StateError('SMTP_HOST is not configured');
    }
    if (_fromEmail.isEmpty) {
      throw StateError('SMTP_FROM_EMAIL is not configured');
    }
  }

  String _plainText({
    required String username,
    required String token,
  }) {
    final link = _resetLink(token);
    return [
      'Hello $username,',
      '',
      'Use the reset token below to reset your CaWil password.',
      '',
      token,
      if (link != null) ...[
        '',
        'Reset link: $link',
      ],
      '',
      'This token expires in 30 minutes. If you did not request this, you can ignore this email.',
    ].join('\n');
  }

  String _html({
    required String username,
    required String token,
  }) {
    final link = _resetLink(token);
    final escapedUsername = _escapeHtml(username);
    final escapedToken = _escapeHtml(token);
    final escapedLink = link == null ? null : _escapeHtml(link);

    return '''
<p>Hello $escapedUsername,</p>
<p>Use the reset token below to reset your CaWil password.</p>
<p style="font-size: 22px; font-weight: 700; letter-spacing: 1px;">$escapedToken</p>
${escapedLink == null ? '' : '<p><a href="$escapedLink">Open reset page</a></p>'}
<p>This token expires in 30 minutes. If you did not request this, you can ignore this email.</p>
''';
  }

  String? _resetLink(String token) {
    final resetUrl = _resetUrl;
    if (resetUrl == null || resetUrl.trim().isEmpty) return null;
    final separator = resetUrl.contains('?') ? '&' : '?';
    return '$resetUrl${separator}token=${Uri.encodeComponent(token)}';
  }
}

String? _readEnv(String key) {
  final value = Platform.environment[key];
  if (value != null && value.trim().isNotEmpty) return value.trim();

  final file = File('.env');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq == -1) continue;
    if (trimmed.substring(0, eq).trim() == key) {
      final envValue = trimmed.substring(eq + 1).trim();
      return envValue.isEmpty ? null : envValue;
    }
  }
  return null;
}

bool _readBoolEnv(String key, {bool defaultValue = false}) {
  final value = _readEnv(key);
  if (value == null) return defaultValue;
  return value == '1' || value.toLowerCase() == 'true';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
