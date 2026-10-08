import 'dart:convert';

import 'package:http/http.dart' as http;

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
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _headers = Map.of(headers);

  final http.Client _client;
  final Map<String, String> _headers;
  final Duration timeout;

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
    final response = await _client.get(
      requestUri,
      headers: {..._headers, 'Accept': 'application/json'},
    ).timeout(timeout);
    return _decode(response);
  }

  Future<Object?> post(String url, Map<String, Object?> body) async {
    final response = await _client
        .post(Uri.parse(url), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(timeout);
    return _decode(response);
  }

  /// Supports the API's array of capability updates as well as JSON objects.
  Future<Object?> patch(String url, Object body) async {
    final response = await _client
        .patch(Uri.parse(url), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(timeout);
    _checkStatus(response);
    return response.bodyBytes.isEmpty ? null : _decode(response);
  }

  Future<Object?> put(String url, Object body) async {
    final response = await _client
        .put(Uri.parse(url), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(timeout);
    _checkStatus(response);
    return response.bodyBytes.isEmpty ? null : _decode(response);
  }

  Future<Object?> delete(String url) async {
    final response = await _client
        .delete(Uri.parse(url), headers: _jsonHeaders)
        .timeout(timeout);
    _checkStatus(response);
    return response.bodyBytes.isEmpty ? null : _decode(response);
  }

  Map<String, String> get _jsonHeaders => {
        ..._headers,
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
