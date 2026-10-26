import '../state/models.dart';

/// Turnos, solicitudes y cambios de turno. Aprobar, ofrecer y tomar turnos
/// pasan por funciones del servidor que validan permisos y estado.
abstract class ShiftsRepository {
  Future<List<Shift>> fetchShifts(DateTime from, DateTime to);

  Future<Shift> createShift({
    required String siteId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? employeeId,
  });

  Future<void> assignShift(String shiftId, String employeeId);

  /// Devuelve cuántos turnos se crearon.
  Future<int> duplicatePreviousWeek(DateTime weekStart);

  Future<List<ShiftRequest>> fetchPendingRequests();

  Future<void> resolveRequest(String requestId, {required bool approve});

  Future<List<SwapOffer>> fetchActiveSwaps();

  Future<void> offerShift(String shiftId);

  Future<void> claimSwap(String swapId);

  /// 7 valores, lunes primero. El gerente puede leer la de su equipo.
  Future<List<bool>> fetchAvailability(String employeeId);

  Future<void> saveAvailability(List<bool> days);
}
