import '../state/models.dart';

abstract class ChatService {
  Future<List<ChatThread>> fetchThreads();

  Future<List<ChatMessage>> fetchMessages(String threadId);

  Future<void> sendMessage({required String threadId, required String text});

  Future<void> markThreadRead(String threadId);

  /// Abre (o reutiliza) un chat directo con otra persona.
  Future<String> openDirectThread(String employeeId);
}
