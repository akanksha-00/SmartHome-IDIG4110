import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_home/src/logging/app_log.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'API request failed (HTTP $statusCode)';
}

/// Shared HTTP handling. The owner should close this client when finished.
class ApiClient {
  ApiClient({
    http.Client? client,
    Map<String, String> headers = const {},
    String? Function()? accessToken,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _headers = Map.of(headers),
        _accessToken = accessToken;

  final http.Client _client;
  final Map<String, String> _headers;
  final String? Function()? _accessToken;
  final Duration timeout;

  // Read at request time, so refreshed tokens replace older ones immediately.
  Map<String, String> get _authHeaders {
    final token = _accessToken?.call();
    return {
      ..._headers,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Object?> get(
    String url, {
    Map<String, String> queryParameters = const {},
  }) async {
    final uri = Uri.parse(url);
    final requestUri = queryParameters.isEmpty
        ? uri
        : uri.replace(queryParameters: {
            ...uri.queryParameters,
            ...queryParameters,
          });
    return _request(
        'GET',
        requestUri.toString(),
        () => _client.get(
              requestUri,
              headers: {..._authHeaders, 'Accept': 'application/json'},
            ));
  }

  Future<Object?> post(String url, Map<String, Object?> body) async {
    return _request(
        'POST',
        url,
        () => _client.post(Uri.parse(url),
            headers: _jsonHeaders, body: jsonEncode(body)));
  }

  /// Supports the API's array of capability updates as well as JSON objects.
  Future<Object?> patch(String url, Object body) async {
    return _request(
        'PATCH',
        url,
        () => _client.patch(Uri.parse(url),
            headers: _jsonHeaders, body: jsonEncode(body)),
        allowEmpty: true);
  }

  Future<Object?> put(String url, Object body) async {
    return _request(
        'PUT',
        url,
        () => _client.put(Uri.parse(url),
            headers: _jsonHeaders, body: jsonEncode(body)),
        allowEmpty: true);
  }

  Future<Object?> delete(String url) async {
    return _request('DELETE', url,
        () => _client.delete(Uri.parse(url), headers: _jsonHeaders),
        allowEmpty: true);
  }

  Future<Object?> _request(
      String method, String url, Future<http.Response> Function() send,
      {bool allowEmpty = false}) async {
    final watch = Stopwatch()..start();
    final endpoint = AppLog.endpoint(url);
    int? status;
    try {
      final response = await send().timeout(timeout);
      status = response.statusCode;
      _checkStatus(response);
      final result =
          allowEmpty && response.bodyBytes.isEmpty ? null : _decode(response);
      AppLog.info(
          'HTTP',
          '$method $endpoint completed | status=$status '
              '| elapsed_ms=${watch.elapsedMilliseconds}');
      return result;
    } catch (error, stackTrace) {
      final reason = switch (error) {
        TimeoutException() => 'Request timed out',
        ApiException() => 'Unsuccessful HTTP status',
        FormatException() => 'Invalid JSON/data format',
        _ => 'Request could not be completed',
      };
      AppLog.error(
          'HTTP',
          '$method $endpoint failed | $reason '
              '| status=${status ?? 'none'} '
              '| elapsed_ms=${watch.elapsedMilliseconds}',
          error: error,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  Map<String, String> get _jsonHeaders => {
        ..._authHeaders,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode);
    }
  }

  Object? _decode(http.Response response) {
    _checkStatus(response);
    // GET and POST operations require JSON; empty responses are not fake data.
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  void close() => _client.close();
}
