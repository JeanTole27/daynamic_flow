import '../state/models.dart';

/// Sesión del usuario. El rol sale del perfil en la base de datos — nunca
/// de lo que el usuario elija en pantalla.
abstract class AuthService {
  /// Sesión guardada al abrir la app (o la que dejó el enlace de invitación).
  Future<SessionUser?> restoreSession();

  Future<SessionUser> signIn({required String email, required String password});

  /// El invitado llega autenticado por el enlace del correo; aquí define su
  /// contraseña y su perfil pasa de 'invited' a 'active'.
  Future<SessionUser> acceptInvite({required String password});

  Future<void> signOut();
}
