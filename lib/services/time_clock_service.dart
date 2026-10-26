import 'dart:typed_data';

import '../state/models.dart';

/// Fichaje. El cliente solo envía la lectura del GPS: el servidor
/// (`clock_in` en `supabase/migrations`) elige el turno, calcula la
/// distancia al sitio y rechaza el fichaje si está fuera del radio, si la
/// ubicación es falsa o si la precisión es mala. Así nadie puede fichar con
/// una ubicación simulada o desde otro sitio modificando la app.
abstract class TimeClockService {
  Future<TimeEntry?> currentEntry();

  Future<TimeEntry> clockIn(LocationFix fix);

  Future<TimeEntry> clockOut(LocationFix fix);

  /// Fichajes que se cruzan con el rango (para "quién trabaja hoy").
  Future<List<TimeEntry>> fetchEntries(DateTime from, DateTime to);

  Future<List<WorkPhoto>> fetchWorkPhotos(String timeEntryId);

  /// Sube una foto de evidencia al fichaje abierto.
  Future<WorkPhoto> uploadWorkPhoto({
    required String timeEntryId,
    required Uint8List jpegBytes,
    LocationFix? fix,
  });
}
