import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';

class RoomStartupGate extends StatelessWidget {
  const RoomStartupGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) {
          if (state.hasLoaded) return child;
          final failed = state.status == RoomLoadStatus.failed;
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!failed) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  Text(failed ? 'Could not load rooms' : 'Loading rooms…'),
                  if (failed) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          context.read<RoomBloc>().add(const RoomsRequested()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
}
