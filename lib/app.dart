import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n/app_lang.dart';

import 'screens/invite_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/shell/app_shell.dart';
import 'services/backend.dart';
import 'services/device_services.dart';
import 'state/app_scaffold_messenger.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';

class TurnosApp extends StatefulWidget {
  const TurnosApp({
    super.key,
    this.backend,
    this.camera,
    this.lang = AppLang.es,
    this.onLangChanged,
  });

  /// null = modo demo con datos en memoria.
  final Backend? backend;
  final PhotoCaptureService? camera;

  /// Idioma al abrir la app y dónde guardar el que se elija.
  final AppLang lang;
  final void Function(AppLang)? onLangChanged;

  @override
  State<TurnosApp> createState() => _TurnosAppState();
}

class _TurnosAppState extends State<TurnosApp> {
  late final AppState _appState = AppState(
    backend: widget.backend,
    camera: widget.camera,
    lang: widget.lang,
    onLangChanged: widget.onLangChanged,
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
      // El idioma elegido en la app también traduce los componentes de
      // Flutter: reloj, calendario y botones de los diálogos del sistema.
      child: ValueListenableBuilder<AppLang>(
        valueListenable: _appState.langListenable,
        builder: (context, lang, _) => MaterialApp(
          title: 'Turnos',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          navigatorKey: rootNavigatorKey,
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
          locale: lang.locale,
          supportedLocales: [for (final l in AppLang.values) l.locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const _StartGate(),
        ),
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
    // Enlace de recuperación de contraseña: primero elegir la nueva.
    if (app.needsNewPassword) return const NewPasswordScreen();
    if (app.restoring) {
      return const SplashView();
    }
    if (!app.isSignedIn) return const LoginScreen();
    if (app.needsInviteAcceptance) return const InviteScreen();
    return const AppShell();
  }
}
