import 'dart:async';
import 'dart:convert';

import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:web_socket_channel/status.dart' as socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketConnectionState { disconnected, connecting, connected }

typedef SocketConnector = WebSocketChannel Function(Uri uri);

/// Create one instance per session/house and share it between stream consumers.
/// This class handles transport only, without assuming a subscription protocol.
class WebSocketService {
  WebSocketService({
    this.endpoint = ApiEndpoints.sensorWebSocket,
    SocketConnector? connector,
    this.connectionTimeout = const Duration(seconds: 15),
  }) : _connector = connector ?? WebSocketChannel.connect;

  final String? endpoint;
  final SocketConnector _connector;
  final Duration connectionTimeout;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _states = StreamController<SocketConnectionState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _pendingConnection;
  SocketConnectionState _state = SocketConnectionState.disconnected;
  int _generation = 0;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<SocketConnectionState> get connectionStates => _states.stream;
  SocketConnectionState get state => _state;

  /// Repeated calls reuse the active connection or its pending handshake.
  Future<void> connect() {
    if (_disposed) {
      return Future.error(StateError('WebSocket service is disposed'));
    }
    if (_state == SocketConnectionState.connected) return Future.value();
    final pending = _pendingConnection;
    if (pending != null) return pending;

    late final Future<void> attempt;
    attempt = _open().whenComplete(() {
      if (identical(_pendingConnection, attempt)) _pendingConnection = null;
    });
    _pendingConnection = attempt;
    return attempt;
  }

  Future<void> _open() async {
    final url = endpoint;
    if (url == null || url.trim().isEmpty) {
      throw UnsupportedError('The sensor WebSocket endpoint is not configured');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['ws', 'wss'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw ArgumentError(
          'WebSocket URL must use ws:// or wss:// and have a host');
    }

    final generation = ++_generation;
    _setState(SocketConnectionState.connecting);
    try {
      final channel = _connector(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (message) {
          if (!_disposed && generation == _generation) _receive(message);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_disposed && generation == _generation) {
            _messages.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (!_disposed && generation == _generation) {
            _channel = null;
            _subscription = null;
            _setState(SocketConnectionState.disconnected);
          }
        },
      );
      await channel.ready.timeout(connectionTimeout);
      if (_disposed ||
          generation != _generation ||
          !identical(_channel, channel)) {
        throw StateError('WebSocket connection was cancelled or closed');
      }
      _setState(SocketConnectionState.connected);
    } catch (_) {
      if (generation == _generation) await disconnect();
      rethrow;
    }
  }

  void _receive(Object? frame) {
    try {
      final String text;
      if (frame is String) {
        text = frame;
      } else if (frame is List<int>) {
        text = utf8.decode(frame);
      } else {
        throw const FormatException('Expected a text or UTF-8 WebSocket frame');
      }
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object message');
      }
      _messages.add(json);
    } catch (error, stackTrace) {
      // Report a malformed frame without discarding later valid messages.
      _messages.addError(error, stackTrace);
    }
  }

  /// For a verified backend subscription message, if one is required.
  void send(Map<String, Object?> message) {
    final channel = _channel;
    if (_disposed ||
        _state != SocketConnectionState.connected ||
        channel == null) {
      throw StateError('Connect the WebSocket before sending a message');
    }
    channel.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    ++_generation;
    _pendingConnection = null;
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    _setState(SocketConnectionState.disconnected);
    await subscription?.cancel();
    if (channel != null) {
      try {
        await channel.sink
            .close(socket_status.normalClosure)
            .timeout(connectionTimeout);
      } catch (error, stackTrace) {
        if (!_disposed) _messages.addError(error, stackTrace);
      }
    }
  }

  void _setState(SocketConnectionState value) {
    if (_state == value) return;
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _messages.close();
    await _states.close();
  }
}
