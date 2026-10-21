import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/models/devices/device_message.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';

// Synthetic fixtures using only the backend's existing device_event fields.
Map<String, Object?> alertJson({
  String deviceId = 'device-013',
  String event = 'smoke',
  Object? value = true,
  bool alert = true,
  String? message = 'smoke detected in bedroom!',
}) =>
    {
      'type': 'device_event',
      'device_id': deviceId,
      'event': event,
      'value': value,
      'alert': alert,
      'notification_message': message,
    };

DeviceMessage alertMessage({
  String deviceId = 'device-013',
  String event = 'smoke',
  Object? value = true,
  bool alert = true,
  String? message = 'smoke detected in bedroom!',
}) =>
    DeviceMessage.fromJson(alertJson(
        deviceId: deviceId,
        event: event,
        value: value,
        alert: alert,
        message: message))!;

NotificationBloc testNotificationBloc({HouseRealtimeRepository? realtime}) {
  final bloc = NotificationBloc(realtime: realtime);
  addTearDown(bloc.close);
  return bloc;
}

Future<NotificationState> waitForNotificationState(
        NotificationBloc bloc, bool Function(NotificationState) matches) =>
    bloc.stream.firstWhere(matches).timeout(const Duration(seconds: 3));

Future<NotificationState> notify(
    NotificationBloc bloc, NotificationEvent event) {
  final next = bloc.stream.first.timeout(const Duration(seconds: 3));
  bloc.add(event);
  return next;
}
