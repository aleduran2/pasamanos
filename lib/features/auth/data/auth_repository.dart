import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../perfil/data/user_profile_repository.dart';
import '../models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<AppUser> signInWithEmail({required String email, required String password});

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String nombre,
  });

  Future<AppUser> signInWithGoogle();

  Future<void> signOut();

  /// Si la cuenta actual tiene contraseña (a diferencia de una cuenta
  /// vinculada solo con Google) — para decidir si mostrar la opción de
  /// cambiarla.
  bool get tieneContrasena;

  /// Cambia el nombre visible, tanto en Firebase Auth como en Firestore
  /// (perfil propio y la copia pública que ve el resto de la comunidad).
  Future<void> actualizarNombre(String nombre);

  /// Cambia la foto de perfil, igual que el nombre.
  Future<void> actualizarFoto(String fotoUrl);

  /// Requiere reautenticación (Firebase Auth exige un login reciente para
  /// esta operación) — por eso pide la contraseña actual, no solo la
  /// nueva.
  Future<void> cambiarContrasena({
    required String actual,
    required String nueva,
  });
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? firebaseAuth, UserProfileRepository? userProfileRepository})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _userProfileRepository = userProfileRepository ?? FirestoreUserProfileRepository();

  final FirebaseAuth _firebaseAuth;
  final UserProfileRepository _userProfileRepository;
  bool _googleSignInInicializado = false;

  @override
  Stream<AppUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_mapearUsuario);

  @override
  AppUser? get currentUser => _mapearUsuario(_firebaseAuth.currentUser);

  AppUser? _mapearUsuario(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      nombre: user.displayName,
      fotoUrl: user.photoURL,
    );
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    // Por si un intento de registro anterior creó el usuario en Auth pero
    // falló al crear su perfil en Firestore (p.ej. Firestore recién
    // habilitado después). crearSiNoExiste no pisa un perfil existente.
    await _userProfileRepository.crearSiNoExiste(
      uid: user.uid,
      nombre: user.displayName ?? email,
      email: email,
    );
    return _mapearUsuario(user)!;
  }

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String nombre,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(nombre);
    await _userProfileRepository.crearSiNoExiste(
      uid: user.uid,
      nombre: nombre,
      email: email,
    );
    return AppUser(uid: user.uid, email: email, nombre: nombre);
  }

  // ID de cliente OAuth "Web" del proyecto pasamanos-dev, autogenerado por
  // Firebase al habilitar Google como proveedor (ver google-services.json,
  // oauth_client con client_type 3). No es un secreto: es un identificador
  // público de cliente OAuth, requerido por Credential Manager en Android
  // para armar el pedido de "Sign in with Google".
  static const _googleServerClientId =
      '304468409357-usied6eia3a0up3gtmrebup8frndn75d.apps.googleusercontent.com';

  @override
  Future<AppUser> signInWithGoogle() async {
    if (!_googleSignInInicializado) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      );
      _googleSignInInicializado = true;
    }

    final cuentaGoogle = await GoogleSignIn.instance.authenticate();
    final autorizacion = await cuentaGoogle.authorizationClient
        .authorizationForScopes(['email']);
    final credencial = GoogleAuthProvider.credential(
      accessToken: autorizacion?.accessToken,
      idToken: cuentaGoogle.authentication.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credencial);
    final user = userCredential.user!;
    await _userProfileRepository.crearSiNoExiste(
      uid: user.uid,
      nombre: user.displayName ?? cuentaGoogle.displayName ?? '',
      email: user.email ?? cuentaGoogle.email,
      fotoUrl: user.photoURL ?? cuentaGoogle.photoUrl,
    );
    return _mapearUsuario(user)!;
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (_googleSignInInicializado) {
      await GoogleSignIn.instance.signOut();
    }
  }

  @override
  bool get tieneContrasena =>
      _firebaseAuth.currentUser?.providerData.any(
        (proveedor) => proveedor.providerId == 'password',
      ) ??
      false;

  @override
  Future<void> actualizarNombre(String nombre) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(nombre);
    // `updateDisplayName` no siempre refleja el cambio en el objeto
    // `User` en memoria hasta este reload explícito.
    await user.reload();
    await _userProfileRepository.actualizarNombre(uid: user.uid, nombre: nombre);
  }

  @override
  Future<void> actualizarFoto(String fotoUrl) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    await user.updatePhotoURL(fotoUrl);
    await user.reload();
    await _userProfileRepository.actualizarFoto(uid: user.uid, fotoUrl: fotoUrl);
  }

  @override
  Future<void> cambiarContrasena({
    required String actual,
    required String nueva,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) return;
    final credencial = EmailAuthProvider.credential(
      email: user.email!,
      password: actual,
    );
    // Firebase exige un login "reciente" para cambiar la contraseña — de
    // ahí pedir la actual y reautenticar antes, en vez de llamar
    // updatePassword directo (tiraría `requires-recent-login`).
    await user.reauthenticateWithCredential(credencial);
    await user.updatePassword(nueva);
  }
}
