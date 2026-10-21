import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:smart_home/src/blocs/notifications/notification_event.dart';
import 'package:smart_home/src/blocs/notifications/notification_state.dart';
import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/models/notifications/device_alert.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';

export 'notification_event.dart';
export 'notification_state.dart';

/// Owns the session's notification feed and read state, entirely in memory.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({HouseRealtimeRepository? realtime})
      : super(NotificationState()) {
    on<NotificationEvent>((event, emit) {
      if (_closing) return;
      switch (event) {
        case NotificationReceived():
          _receive(event.message, emit);
        case NotificationRead():
          if (!state.notifications
              .any((item) => item.sequence == event.sequence && !item.isRead)) {
            return;
          }
          emit(NotificationState(notifications: [
            for (final item in state.notifications)
              item.sequence == event.sequence
                  ? item.copyWith(isRead: true)
                  : item,
          ]));
        case NotificationsReadAll():
          if (state.unreadCount == 0) return;
          emit(NotificationState(notifications: [
            for (final item in state.notifications)
              item.isRead ? item : item.copyWith(isRead: true),
          ]));
      }
    });
    _subscription = realtime?.messages.listen(
      (message) {
        if (!_closing) add(NotificationReceived(message));
      },
      onError: (Object error, StackTrace stackTrace) {
        // DeviceBloc exposes the shared connection error in the app bar.
        // Keep the last notification history while the connection recovers.
      },
    );
  }

  StreamSubscription<DeviceMessage>? _subscription;
  final _activeAlerts = <(String, String)>{};
  int _sequence = 0;
  bool _closing = false;

  void _receive(DeviceMessage message, Emitter<NotificationState> emit) {
    final event = message.event;
    // State reports carry no alert decision. Thresholds belong to the backend.
    if (event == null) return;
    final key = (message.deviceId, event);
    if (!message.alert) {
      if (!_activeAlerts.remove(key)) return;
      emit(NotificationState(notifications: [
        for (final item in state.notifications)
          (item.deviceId, item.event) == key && item.isActive
              ? item.copyWith(isActive: false)
              : item,
      ]));
      return;
    }
    if (!_activeAlerts.add(key)) return;
    final text = message.notificationMessage;
    emit(NotificationState(notifications: [
      DeviceAlert(
        sequence: ++_sequence,
        deviceId: message.deviceId,
        event: event,
        value: message.value,
        message: text != null && text.trim().isNotEmpty
            ? text
            : '${message.deviceId}: $event alert',
      ),
      ...state.notifications.take(49),
    ]));
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _subscription?.cancel();
    // The shared repository/connection is owned by the house's DeviceBloc.
    await super.close();
  }
}
