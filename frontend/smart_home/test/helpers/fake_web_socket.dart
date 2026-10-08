import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeChannel implements WebSocketChannel {
  FakeChannel({bool readyNow = true}) {
    if (readyNow) handshake.complete();
  }

  final handshake = Completer<void>();
  final incoming = StreamController<Object?>();
  final outgoing = StreamController<Object?>.broadcast();

  @override
  Future<void> get ready => handshake.future;
  @override
  Stream<Object?> get stream => incoming.stream;
  @override
  late final WebSocketSink sink = FakeSink(incoming, outgoing);
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSink implements WebSocketSink {
  FakeSink(this.incoming, this.outgoing);
  final StreamController<Object?> incoming;
  final StreamController<Object?> outgoing;

  @override
  void add(dynamic value) => outgoing.add(value);
  @override
  Future<void> close([int? code, String? reason]) async {
    await incoming.close();
    await outgoing.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
