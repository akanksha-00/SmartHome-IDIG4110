import 'package:flutter/widgets.dart';
import 'package:smart_home/src/repositories/device_repository.dart';

/// Makes the single startup repository available to screens when integrated.
class DeviceRepositoryScope extends InheritedNotifier<DeviceRepository> {
  const DeviceRepositoryScope({
    super.key,
    required DeviceRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static DeviceRepository of(BuildContext context) {
    final repository = context
        .dependOnInheritedWidgetOfExactType<DeviceRepositoryScope>()
        ?.notifier;
    if (repository == null) {
      throw StateError('No DeviceRepositoryScope is available');
    }
    return repository;
  }
}
