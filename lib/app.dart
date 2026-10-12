import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'camera/camera_screen.dart';
import 'core/theme/app_theme.dart';
import 'history/history_screen.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_screen.dart';
import 'survey/survey_controller.dart';

class GeoPatriotApp extends StatelessWidget {
  const GeoPatriotApp({super.key});

  /// Bangun root widget aplikasi: provider pengaturan global, tema, route
  /// awal, dan daftar navigasi.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => SurveyController()),
      ],
      child: MaterialApp(
        title: 'GeoPatriot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (context) => const CameraScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/history': (context) => const HistoryScreen(),
        },
      ),
    );
  }
}
