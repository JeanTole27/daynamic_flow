import '../state/models.dart';

/// CONEXIÓN PENDIENTE — no implementada a propósito.
///
/// Reemplaza la lista `Employee` fija en `AppState`. Debe traer/editar el
/// equipo real del negocio y enviar invitaciones por correo.
abstract class TeamRepository {
  Stream<List<Employee>> watchTeam();

  Future<void> inviteEmployee({
    required String name,
    required String email,
    required String role,
  });

  Future<void> updateEmployee(Employee employee);

  Future<void> setEmployeeStatus(int employeeId, EmployeeStatus status);
}
