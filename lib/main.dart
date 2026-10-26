import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'services/backend.dart';
import 'services/device/geolocator_location_service.dart';
import 'services/device/image_picker_photo_service.dart';
import 'services/supabase/supabase_backend.dart';

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

  runApp(TurnosApp(backend: backend, camera: ImagePickerPhotoService()));
}
