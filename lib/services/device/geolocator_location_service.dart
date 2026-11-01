import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../state/models.dart';
import '../device_services.dart';

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// Tiempo que se le da al GPS del teléfono antes de pedir ayuda al
  /// servicio de ubicación de Google.
  static const _gpsTimeLimit = Duration(seconds: 15);
  static const _fusedTimeLimit = Duration(seconds: 20);

  @override
  Future<LocationFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException('location_off');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      throw const AppException('location_denied');
    }

    try {
      return _toFix(await _read());
    } on TimeoutException {
      throw const AppException('location_timeout');
    } on LocationServiceDisabledException {
      throw const AppException('location_off');
    }
  }

  /// Siempre una lectura nueva: una posición en caché podría ser de antes
  /// de llegar (o de salir) del sitio.
  Future<Position> _read() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: _fusedTimeLimit,
        ),
      );
    }
    // En Android, el servicio de Google pide activar "Precisión de la
    // ubicación" con un diálogo; si la persona lo rechaza, no hay lectura.
    // Primero se usa el GPS del sistema, que no muestra ese diálogo.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          forceLocationManager: true,
          timeLimit: _gpsTimeLimit,
        ),
      );
    } on TimeoutException {
      // Sin señal de GPS (p. ej. bajo techo): el servicio de Google puede
      // ubicar con wifi y antenas. Aquí sí puede aparecer su diálogo.
      return Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: _fusedTimeLimit,
        ),
      );
    }
  }

  LocationFix _toFix(Position p) => LocationFix(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: p.accuracy,
    isMocked: p.isMocked,
  );
}
