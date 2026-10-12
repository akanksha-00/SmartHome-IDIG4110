import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';

/// The dropdown and floor-plan clicks use the same selected API room ID.
class RoomSelector extends StatelessWidget {
  const RoomSelector({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room'),
            const SizedBox(height: 12),
            DropdownMenu<String>(
              key: ValueKey(state.selectedRoomId),
              width: 200,
              initialSelection: state.selectedRoomId,
              enabled: state.rooms.isNotEmpty,
              selectOnly: true,
              onSelected: (value) {
                if (value != null) {
                  context.read<RoomBloc>().add(RoomSelected(value));
                }
              },
              dropdownMenuEntries: [
                for (final room in state.rooms)
                  DropdownMenuEntry(value: room.id, label: room.name),
              ],
            ),
          ],
        ),
      );
}
