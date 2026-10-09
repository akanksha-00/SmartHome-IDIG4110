import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/devices/device_bloc.dart';
import 'package:smart_home/src/blocs/rooms/room_bloc.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/config/api_endpoints.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/repositories/room_repository.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/services/web_socket_service.dart';
import 'package:smart_home/src/screen/dashboard/dashboard.dart';
import 'package:smart_home/src/theme/app_theme.dart';
import 'package:smart_home/src/widgets/device_startup_gate.dart';
import 'package:smart_home/src/widgets/room_startup_gate.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp(
      {super.key, this.deviceRepository, this.roomRepository, this.realtime});

  final DeviceRepository? deviceRepository;
  final RoomRepository? roomRepository;
  // Test/integration seam. With a supplied HTTP repository, realtime is opt-in.
  final HouseRealtimeRepository? realtime;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ApiClient? _ownedApiClient;
  late final DeviceRepository _deviceRepository;
  late final RoomRepository _roomRepository;
  HouseRealtimeRepository? _realtime;
  DeviceBloc? _deviceBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final suppliedRepository = widget.deviceRepository;
    if (suppliedRepository != null) {
      _deviceRepository = suppliedRepository;
    } else {
      final apiClient = ApiClient();
      _ownedApiClient = apiClient;
      _deviceRepository = DeviceRepository(
        apiClient: apiClient,
        houseId: AppConfig.houseId,
      );
    }
    _roomRepository = widget.roomRepository ??
        RoomRepository(
          apiClient: _deviceRepository.apiClient,
          houseId: _deviceRepository.houseId,
        );
    _realtime = widget.realtime ??
        (widget.deviceRepository == null
            ? HouseRealtimeRepository(
                socket: WebSocketService(
                    endpoint:
                        ApiEndpoints.houseWebSocket(_deviceRepository.houseId)))
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
    if (_ownedApiClient != null) {
      _ownedApiClient?.close();
    }
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, child) => AppSettingsScope(
        controller: appSettings,
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<DeviceRepository>.value(
                value: _deviceRepository),
            RepositoryProvider<RoomRepository>.value(value: _roomRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<DeviceBloc>(
                lazy: false,
                create: (_) => _deviceBloc = DeviceBloc(
                    repository: _deviceRepository, realtime: _realtime)
                  ..add(const DevicesRequested()),
              ),
              BlocProvider<RoomBloc>(
                lazy: false,
                create: (_) => RoomBloc(repository: _roomRepository)
                  ..add(const RoomsRequested()),
              ),
            ],
            child: MaterialApp(
              title: 'Smart Home',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: appSettings.themeMode,
              home: const DeviceStartupGate(
                child: RoomStartupGate(child: Dashboard()),
              ),
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      ),
    );
  }
}
