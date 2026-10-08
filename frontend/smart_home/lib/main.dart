import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/config/app_config.dart';
import 'package:smart_home/src/repositories/api_client.dart';
import 'package:smart_home/src/repositories/device_repository.dart';
import 'package:smart_home/src/screen/dashboard/dashboard.dart';
import 'package:smart_home/src/theme/app_theme.dart';
import 'package:smart_home/src/widgets/device_repository_scope.dart';
import 'package:smart_home/src/widgets/device_startup_gate.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.deviceRepository});

  final DeviceRepository? deviceRepository;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ApiClient? _ownedApiClient;
  late final DeviceRepository _deviceRepository;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    if (_ownedApiClient != null) {
      _deviceRepository.dispose();
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
        child: DeviceRepositoryScope(
          repository: _deviceRepository,
          child: MaterialApp(
            title: 'Smart Home',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: appSettings.themeMode,
            home: DeviceStartupGate(
              repository: _deviceRepository,
              child: const Dashboard(),
            ),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
