import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smart_home/src/repositories/device_repository.dart';

/// Loads once on startup and shows the app only after house devices are cached.
class DeviceStartupGate extends StatefulWidget {
  const DeviceStartupGate({
    super.key,
    required this.repository,
    required this.child,
  });

  final DeviceRepository repository;
  final Widget child;

  @override
  State<DeviceStartupGate> createState() => _DeviceStartupGateState();
}

class _DeviceStartupGateState extends State<DeviceStartupGate> {
  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant DeviceStartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    // Defer notifications until the initial widget tree has finished building.
    scheduleMicrotask(() {
      if (mounted) unawaited(_load(widget.repository));
    });
  }

  Future<void> _load(DeviceRepository repository) async {
    try {
      await repository.loadDevices();
    } catch (error) {
      // The repository exposes failure state; keep the error handled for startup.
      debugPrint('Could not load house devices: $error');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.repository,
        builder: (context, child) {
          switch (widget.repository.loadState) {
            case DeviceLoadState.loaded:
              return widget.child;
            case DeviceLoadState.failed:
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load devices'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => unawaited(_load(widget.repository)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            case DeviceLoadState.idle:
            case DeviceLoadState.loading:
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading devices…'),
                    ],
                  ),
                ),
              );
          }
        },
      );
}
