import '../state/models.dart';

/// CONEXIÓN PENDIENTE — no implementada a propósito.
///
/// Reemplaza el login simulado de `AppState.loginAs` / `AppState.acceptInvite`.
/// Debe validar credenciales contra el backend, devolver un token/sesión y el
/// rol real del usuario (en vez del rol elegido a mano en el prototipo).
abstract class AuthService {
  Future<UserRole> signIn({required String email, required String password});

  Future<void> acceptInvite({
    required String inviteToken,
    required String password,
  });

  Future<void> signOut();

  /// Sesión restaurada al abrir la app (token guardado, biometría, etc.).
  Future<UserRole?> restoreSession();
}
