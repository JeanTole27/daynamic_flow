import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'state/app_scaffold_messenger.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class TurnosApp extends StatefulWidget {
  const TurnosApp({super.key});

  @override
  State<TurnosApp> createState() => _TurnosAppState();
}

class _TurnosAppState extends State<TurnosApp> {
  late final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _appState,
      child: MaterialApp(
        title: 'Turnos',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const LoginScreen(),
      ),
    );
  }
}
