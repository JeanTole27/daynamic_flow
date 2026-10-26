import 'package:flutter/material.dart';

import 'screens/invite_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell/app_shell.dart';
import 'services/backend.dart';
import 'services/device_services.dart';
import 'state/app_scaffold_messenger.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class TurnosApp extends StatefulWidget {
  const TurnosApp({super.key, this.backend, this.camera});

  /// null = modo demo con datos en memoria.
  final Backend? backend;
  final PhotoCaptureService? camera;

  @override
  State<TurnosApp> createState() => _TurnosAppState();
}

class _TurnosAppState extends State<TurnosApp> {
  late final AppState _appState = AppState(
    backend: widget.backend,
    camera: widget.camera,
  );

  @override
  void initState() {
    super.initState();
    if (!_appState.isDemo) _appState.restoreSession();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

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
        home: const _StartGate(),
      ),
    );
  }
}

/// Primera pantalla: espera la sesión guardada y decide a dónde ir.
class _StartGate extends StatelessWidget {
  const _StartGate();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.isDemo) return const LoginScreen();
    if (app.restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.lime)),
      );
    }
    if (!app.isSignedIn) return const LoginScreen();
    if (app.needsInviteAcceptance) return const InviteScreen();
    return const AppShell();
  }
}
