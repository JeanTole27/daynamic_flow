import '../state/models.dart';

/// Sesión del usuario. El rol sale del perfil en la base de datos — nunca
/// de lo que el usuario elija en pantalla.
abstract class AuthService {
  /// Sesión guardada al abrir la app (o la que dejó el enlace de invitación).
  Future<SessionUser?> restoreSession();

  Future<SessionUser> signIn({required String email, required String password});

  /// Registro de un gerente: crea su cuenta y su organización. Devuelve
  /// null si Supabase pide confirmar el correo antes de entrar; la
  /// organización se crea al volver con el enlace de confirmación.
  Future<SessionUser?> signUpManager({
    required String fullName,
    required String orgName,
    required String email,
    required String password,
  });

  /// El invitado llega autenticado por el enlace del correo; aquí define su
  /// contraseña y su perfil pasa de 'invited' a 'active'.
  Future<SessionUser> acceptInvite({required String password});

  /// Avisa de cada inicio de sesión, también los que llegan desde fuera de
  /// la app (enlace de invitación o de confirmación de correo), que la app
  /// no inició ella misma.
  Stream<void> get onSignedIn;

  Future<void> signOut();
}
