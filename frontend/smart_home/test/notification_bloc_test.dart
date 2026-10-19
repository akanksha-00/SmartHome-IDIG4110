import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/dummyData/notification_data.dart';

Future<NotificationState> dispatch(
    NotificationBloc bloc, NotificationEvent event) {
  final next = bloc.stream.first.timeout(const Duration(seconds: 3));
  bloc.add(event);
  return next;
}

void main() {
  test('loads newest first without modifying the supplied demo snapshot',
      () async {
    final bloc = NotificationBloc();
    addTearDown(bloc.close);
    expect(bloc.state.notifications, isEmpty);
    final data =
        dummyNotifications(now: DateTime(2026, 10, 19, 12)).reversed.toList();
    final event = NotificationsLoaded(data);
    data.clear();
    final loaded = await dispatch(bloc, event);
    expect(loaded.notifications, hasLength(5));
    expect(loaded.notifications.first.id, 'demo-smoke');
    expect(loaded.notifications.last.id, 'demo-device-added');
    expect(loaded.unreadCount, 3);
    expect(() => loaded.notifications.clear(), throwsUnsupportedError);
  });

  test('reading one and then all preserves content and previous state',
      () async {
    final bloc = NotificationBloc();
    addTearDown(bloc.close);
    final loaded =
        await dispatch(bloc, NotificationsLoaded(dummyNotifications()));
    final read = await dispatch(bloc, const NotificationRead('demo-smoke'));
    expect(read.unreadCount, 2);
    expect(read.notifications.first.isRead, isTrue);
    expect(loaded.notifications.first.isRead, isFalse);
    expect(
        read.notifications.first.message, loaded.notifications.first.message);
    expect(read.notifications.first.createdAt,
        loaded.notifications.first.createdAt);
    expect(read.notifications[1].isRead, isFalse);
    final allRead = await dispatch(bloc, const NotificationsReadAll());
    expect(allRead.unreadCount, 0);
    expect(allRead.notifications, hasLength(5));
    expect(allRead.notifications.every((item) => item.isRead), isTrue);
    expect(read.unreadCount, 2);
  });

  test('unknown and repeated read actions leave the feed unchanged', () async {
    final bloc = NotificationBloc();
    await dispatch(bloc, NotificationsLoaded(dummyNotifications()));
    await dispatch(bloc, const NotificationsReadAll());
    final previous = bloc.state;
    final emissions = <NotificationState>[];
    final subscription = bloc.stream.listen(emissions.add);
    bloc.add(const NotificationRead('missing'));
    bloc.add(const NotificationRead('demo-smoke'));
    bloc.add(const NotificationsReadAll());
    await bloc.close();
    await subscription.cancel();
    expect(bloc.state, same(previous));
    expect(emissions, isEmpty);
  });
}
