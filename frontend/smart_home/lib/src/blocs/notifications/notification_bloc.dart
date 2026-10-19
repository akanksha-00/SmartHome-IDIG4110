import 'package:bloc/bloc.dart';
import 'package:smart_home/src/blocs/notifications/notification_event.dart';
import 'package:smart_home/src/blocs/notifications/notification_state.dart';

export 'notification_event.dart';
export 'notification_state.dart';

/// Owns the session's notification feed and read state, entirely in memory.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc() : super(NotificationState()) {
    on<NotificationEvent>((event, emit) {
      switch (event) {
        case NotificationsLoaded():
          final notifications = event.notifications.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          emit(NotificationState(notifications: notifications));
        case NotificationRead():
          if (!state.notifications
              .any((item) => item.id == event.id && !item.isRead)) {
            return;
          }
          emit(NotificationState(notifications: [
            for (final item in state.notifications)
              item.id == event.id ? item.copyWith(isRead: true) : item,
          ]));
        case NotificationsReadAll():
          if (state.unreadCount == 0) return;
          emit(NotificationState(notifications: [
            for (final item in state.notifications)
              item.isRead ? item : item.copyWith(isRead: true),
          ]));
      }
    });
  }
}
