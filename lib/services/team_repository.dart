import '../state/models.dart';

abstract class TeamRepository {
  Future<List<Employee>> fetchTeam();

  /// Todos los sitios de la organización, activos e inactivos.
  Future<List<Site>> fetchSites();

  /// Crea el sitio si `site.id` está vacío; si no, lo actualiza.
  Future<void> saveSite(Site site);

  Future<void> setSiteActive(String siteId, bool active);

  /// Lo ejecuta la Edge Function `invite-employee` (usa la service role, que
  /// nunca debe estar en la app).
  Future<void> inviteEmployee({
    required String name,
    required String email,
    required String positionEs,
    required String positionEn,
    required double hourlyRate,
  });

  Future<void> setEmployeeStatus(String employeeId, EmployeeStatus status);
}
