import 'dart:async';

import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/services/web_socket_service.dart';

/// Owns one house connection, with bounded reconnect backoff. Consumers share
/// its stream; no per-sensor sockets or invented subscription messages.
class HouseRealtimeRepository {
  HouseRealtimeRepository({
    required this.socket,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 30),
    ],
  }) {
    if (retryDelays.isEmpty) throw ArgumentError('Provide retry delays');
    _messagesSubscription = socket.messages.listen((json) {
      try {
        final message = DeviceMessage.fromJson(json);
        if (message != null) _messages.add(message);
      } catch (error, stack) {
        _messages.addError(error, stack);
      }
    },
        onError: (Object error, StackTrace stack) =>
            _messages.addError(error, stack));
    _stateSubscription = socket.connectionStates.listen((state) {
      if (state == SocketConnectionState.connected) {
        _attempt = 0;
        _retry?.cancel();
        _retry = null;
      } else if (state == SocketConnectionState.disconnected) {
        _scheduleRetry();
      }
    });
  }

  final WebSocketService socket;
  final List<Duration> retryDelays;
  final _messages = StreamController<DeviceMessage>.broadcast();
  late final StreamSubscription<Map<String, dynamic>> _messagesSubscription;
  late final StreamSubscription<SocketConnectionState> _stateSubscription;
  Timer? _retry;
  int _attempt = 0;
  bool _started = false;
  bool _disposed = false;

  Stream<DeviceMessage> get messages => _messages.stream;
  Stream<SocketConnectionState> get connectionStates => socket.connectionStates;
  SocketConnectionState get connectionState => socket.state;

  void start() {
    if (_disposed) return;
    _started = true;
    if (socket.state != SocketConnectionState.disconnected) return;
    _retry?.cancel();
    _retry = null;
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      await socket.connect();
    } catch (error, stack) {
      if (!_disposed) {
        _messages.addError(error, stack);
        _scheduleRetry();
      }
    }
  }

  void _scheduleRetry() {
    if (!_started || _disposed || _retry != null) return;
    final delay = retryDelays[_attempt.clamp(0, retryDelays.length - 1)];
    _attempt++;
    _retry = Timer(delay, () {
      _retry = null;
      if (!_disposed) unawaited(_connect());
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    await _messagesSubscription.cancel();
    await _stateSubscription.cancel();
    await socket.dispose();
    await _messages.close();
  }
}
