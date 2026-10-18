import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';

/// Startup UI consumes BLoC state; rebuilding this widget never fetches data.
class DeviceStartupGate extends StatelessWidget {
  const DeviceStartupGate({super.key, required this.child, this.onSignOut});
  final Widget child;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => BlocBuilder<DeviceBloc, DeviceState>(
        builder: (context, state) {
          if (state.hasLoaded) return child;
          if (state.status == DeviceLoadStatus.failed) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load devices'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context
                          .read<DeviceBloc>()
                          .add(const DevicesRequested()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    if (onSignOut != null)
                      TextButton(
                          onPressed: onSignOut,
                          child: const Text('Back to sign in')),
                  ],
                ),
              ),
            );
          }
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Loading devices…'),
                  if (onSignOut != null)
                    TextButton(
                        onPressed: onSignOut,
                        child: const Text('Back to sign in')),
                ],
              ),
            ),
          );
        },
      );
}
