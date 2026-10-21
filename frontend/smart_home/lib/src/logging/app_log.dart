import 'package:flutter/foundation.dart';

/// Console diagnostics only: no persistence, telemetry, or backend payloads.
abstract final class AppLog {
  static const enabled =
      bool.fromEnvironment('SMART_HOME_LOGS', defaultValue: !kReleaseMode);

  static void info(String source, String message) =>
      _write('INFO', source, message);

  static void warning(String source, String message,
          {Object? error, StackTrace? stackTrace}) =>
      _write('WARN', source, message, error: error, stackTrace: stackTrace);

  static void error(String source, String message,
          {Object? error, StackTrace? stackTrace}) =>
      _write('ERROR', source, message, error: error, stackTrace: stackTrace);

  /// Only log the address/path, never URL credentials, query tokens or fragments.
  static String endpoint(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '(unconfigured endpoint)';
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }

  static void _write(String level, String source, String message,
      {Object? error, StackTrace? stackTrace}) {
    if (!enabled) return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    // Exception text can contain credentials, response bodies or raw frames.
    // Call sites supply a controlled explanation; retain only the error type.
    final type = error == null ? '' : ' | error=${error.runtimeType}';
    debugPrint('[SmartHome][$timestamp][$level][$source] $message$type');
    if (stackTrace != null) {
      // Stream errors can carry non-VM stack formats. Print them as text so
      // diagnostic formatting cannot interrupt error handling or rollback.
      final frames = stackTrace.toString().split('\n').take(10).join('\n');
      debugPrint('[SmartHome][$source] stack\n$frames');
    }
  }
}
