import '../state/models.dart';

/// CONEXIÓN PENDIENTE — no implementada a propósito.
///
/// Reemplaza `AppState.week`, `AppState.requests` y `AppState.swaps`, que
/// hoy viven en memoria. Debe sincronizar el calendario compartido por
/// todo el equipo (lo que un empleado ofrece, el gerente lo tiene que ver
/// en tiempo real) — candidato natural a un stream / websocket, no solo
/// REST.
abstract class ShiftsRepository {
  Stream<List<WeekDay>> watchWeek(DateTime weekStart);

  Future<void> createShift({
    required int employeeId,
    required int weekdayIndex,
    required String timeLabel,
  });

  Future<void> duplicatePreviousWeek(DateTime weekStart);

  Stream<List<ShiftRequest>> watchRequests();

  Future<void> resolveRequest(int requestId, {required bool approve});

  Stream<List<SwapOffer>> watchSwapOffers();

  Future<void> offerShift({
    required int employeeId,
    required int weekdayIndex,
    required String timeLabel,
  });

  Future<void> claimSwap(int swapId);
}
