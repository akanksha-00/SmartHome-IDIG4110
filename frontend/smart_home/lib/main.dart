import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/repositories/auth_repository.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/repositories/room_repository.dart';
import 'package:smart_home/src/repositories/house_realtime_repository.dart';
import 'package:smart_home/src/screen/authentication/authentication_gate.dart';
import 'package:smart_home/src/theme/app_theme.dart';
import 'package:smart_home/src/widgets/house_session.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp(
      {super.key,
      this.authRepository,
      this.deviceRepository,
      this.roomRepository,
      this.realtime});

  final AuthRepository? authRepository;
  final DeviceRepository? deviceRepository;
  final RoomRepository? roomRepository;
  // Test/integration seam. With a supplied HTTP repository, realtime is opt-in.
  final HouseRealtimeRepository? realtime;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? AuthRepository();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, child) => AppSettingsScope(
        controller: appSettings,
        child: RepositoryProvider<AuthRepository>.value(
          value: _authRepository,
          child: BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(repository: _authRepository),
            child: MaterialApp(
              title: 'Smart Home',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: appSettings.themeMode,
              home: AuthenticationGate(
                signedInBuilder: (context, user) => HouseSession(
                  key: ValueKey(user.id),
                  deviceRepository: widget.deviceRepository,
                  roomRepository: widget.roomRepository,
                  realtime: widget.realtime,
                ),
              ),
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      ),
    );
  }
}
