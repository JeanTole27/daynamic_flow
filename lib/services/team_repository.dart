import '../state/models.dart';

abstract class TeamRepository {
  Future<List<Employee>> fetchTeam();

  Future<List<Site>> fetchSites();

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
