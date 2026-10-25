import '../state/models.dart';

/// CONEXIÓN PENDIENTE — no implementada a propósito.
///
/// Reemplaza `AppState.messagesByThread`. Necesita mensajería en tiempo
/// real (Firestore streams, websockets, etc.) — el mock actual solo
/// existe en memoria de esta sesión de la app.
abstract class ChatService {
  Stream<List<ChatMessage>> watchThread(String threadId);

  Future<void> sendMessage({required String threadId, required String text});
}
