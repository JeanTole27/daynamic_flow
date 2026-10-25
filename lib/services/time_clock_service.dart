/// CONEXIÓN PENDIENTE — no implementada a propósito.
///
/// Reemplaza `AppState.clockToggle`. El prototipo confía en un flag local
/// (`gpsInside`); una implementación real necesita:
///  1. Permiso de ubicación (foreground, y en Android background si se
///     quiere detectar salida del radio sin abrir la app) vía el paquete
///     `geolocator` o similar.
///  2. Enviar la posición al servidor y que **el servidor** valide la
///     distancia al local — nunca confiar solo en el cliente, o cualquiera
///     puede falsificar el fichaje con una ubicación simulada.
///  3. Persistir el fichaje (hora entrada/salida + ubicación) para reportes.
abstract class TimeClockService {
  Future<ClockStatus> clockIn({
    required double latitude,
    required double longitude,
  });

  Future<ClockStatus> clockOut({
    required double latitude,
    required double longitude,
  });

  Future<ClockStatus> currentStatus();
}

class ClockStatus {
  const ClockStatus({
    required this.clockedIn,
    required this.since,
    required this.insideAllowedRadius,
  });

  final bool clockedIn;
  final DateTime? since;
  final bool insideAllowedRadius;
}
