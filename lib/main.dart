import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'i18n/app_lang.dart';
import 'services/backend.dart';
import 'services/device/geolocator_location_service.dart';
import 'services/device/image_picker_photo_service.dart';
import 'services/supabase/supabase_backend.dart';

/// Clave del idioma elegido, guardado en el teléfono.
const _langKey = 'lang';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Backend? backend;
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
    backend = supabaseBackend(
      Supabase.instance.client,
      const GeolocatorLocationService(),
    );
  }

  final prefs = SharedPreferencesAsync();
  final lang = AppLang.resolve(
    await prefs.getString(_langKey),
    PlatformDispatcher.instance.locale,
  );

  runApp(
    TurnosApp(
      backend: backend,
      camera: ImagePickerPhotoService(),
      lang: lang,
      onLangChanged: (l) => prefs.setString(_langKey, l.name),
    ),
  );
}
