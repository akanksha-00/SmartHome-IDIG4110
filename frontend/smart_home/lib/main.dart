import 'package:flutter/material.dart';
import 'package:smart_home/src/controllers/app_settings_controller.dart';
import 'package:smart_home/src/screen/dashboard/dashboard.dart';
import 'package:smart_home/src/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, child) => AppSettingsScope(
        controller: appSettings,
        child: MaterialApp(
          title: 'Smart Home',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appSettings.themeMode,
          home: const Dashboard(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
