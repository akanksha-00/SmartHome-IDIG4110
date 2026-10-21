import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/notifications/notification_bloc.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';
import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/repositories/room_repository.dart';
import 'package:smart_home/src/screen/dashboard/dashboard.dart';
import 'package:smart_home/src/services/web_socket_service.dart';
import 'package:smart_home/src/widgets/device_startup_gate.dart';
import 'package:smart_home/src/widgets/room_startup_gate.dart';

/// Device/room state and the socket exist only while a user is signed in.
class HouseSession extends StatefulWidget {
  const HouseSession(
      {super.key,
      this.apiClient,
      this.houseId,
      this.deviceRepository,
      this.roomRepository,
      this.realtime})
      : assert(deviceRepository != null || houseId != null);

  final ApiClient? apiClient;
  final String? houseId;
  final DeviceRepository? deviceRepository;
  final RoomRepository? roomRepository;
  final HouseRealtimeRepository? realtime;

  @override
  State<HouseSession> createState() => _HouseSessionState();
}

class _HouseSessionState extends State<HouseSession>
    with WidgetsBindingObserver {
  ApiClient? _ownedApiClient;
  late final DeviceRepository _devices;
  late final RoomRepository _rooms;
  HouseRealtimeRepository? _realtime;
  DeviceBloc? _deviceBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<AuthRepository>();
    if (widget.deviceRepository != null) {
      _devices = widget.deviceRepository!;
    } else {
      final client =
          widget.apiClient ?? ApiClient(accessToken: () => auth.accessToken);
      if (widget.apiClient == null) _ownedApiClient = client;
      _devices = DeviceRepository(apiClient: client, houseId: widget.houseId!);
    }
    _rooms = widget.roomRepository ??
        RoomRepository(
            apiClient: _devices.apiClient, houseId: _devices.houseId);
    _realtime = widget.realtime ??
        (widget.deviceRepository == null
            ? HouseRealtimeRepository(
                socket: WebSocketService(
                    endpoint: ApiEndpoints.houseWebSocket(_devices.houseId),
                    accessToken: () => auth.accessToken))
            : null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _realtime != null) {
      _realtime!.start();
      _deviceBloc?.add(const DevicesRequested(force: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ownedApiClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<DeviceRepository>.value(value: _devices),
          RepositoryProvider<RoomRepository>.value(value: _rooms),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<DeviceBloc>(
              lazy: false,
              create: (_) => _deviceBloc =
                  DeviceBloc(repository: _devices, realtime: _realtime)
                    ..add(const DevicesRequested()),
            ),
            BlocProvider<RoomBloc>(
              lazy: false,
              create: (_) =>
                  RoomBloc(repository: _rooms)..add(const RoomsRequested()),
            ),
            BlocProvider<NotificationBloc>(
              lazy: false,
              create: (_) => NotificationBloc(realtime: _realtime),
            ),
          ],
          child: DeviceStartupGate(
              onSignOut: () => context.read<AuthCubit>().signOut(),
              child: RoomStartupGate(
                  onSignOut: () => context.read<AuthCubit>().signOut(),
                  child: const Dashboard())),
        ),
      );
}
