import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../state/models.dart';
import '../device_services.dart';

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

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
      // Siempre una lectura nueva: una posición en caché podría ser de
      // antes de llegar (o de salir) del sitio.
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyMeters: p.accuracy,
        isMocked: p.isMocked,
      );
    } on TimeoutException {
      throw const AppException('location_timeout');
    }
  }
}
