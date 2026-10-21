import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_home/src/logging/app_log.dart';

/// Logs uncaught failures while retaining Flutter/platform error handling.
void installAppErrorLogging() {
  Bloc.observer = AppBlocObserver();
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.error('Flutter', 'Unhandled framework error',
        error: details.exception, stackTrace: details.stack);
    previousFlutterHandler?.call(details);
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLog.error('Platform', 'Unhandled asynchronous error',
        error: error, stackTrace: stackTrace);
    return previousPlatformHandler?.call(error, stackTrace) ?? false;
  };
}

/// No event/state dumps: those can include user data and complete device states.
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppLog.error('BLoC', 'Unhandled error in ${bloc.runtimeType}',
        error: error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
