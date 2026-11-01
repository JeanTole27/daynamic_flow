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

  /// Vuelve a enviar el correo a alguien invitado que aún no aceptó.
  Future<void> resendInvite(String employeeId);

  /// Anula una invitación que aún no se aceptó (borra a la persona).
  Future<void> cancelInvite(String employeeId);

  /// El gerente cambia nombre, cargo, tarifa o rol de alguien de su equipo.
  Future<void> updateEmployee({
    required String employeeId,
    required String fullName,
    required String positionEs,
    required String positionEn,
    required double hourlyRate,
    required UserRole role,
  });
}
