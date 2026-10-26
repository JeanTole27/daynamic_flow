import 'dart:typed_data';

import '../state/models.dart';

/// GPS del dispositivo. Lanza [AppException] con los códigos
/// `location_denied`, `location_off` o `location_timeout`.
abstract class LocationService {
  Future<LocationFix> currentFix();
}

/// Cámara para fotos de evidencia. Devuelve null si el usuario cancela.
abstract class PhotoCaptureService {
  Future<Uint8List?> takePhoto();
}
