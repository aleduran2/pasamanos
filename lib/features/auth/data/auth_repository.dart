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
    return _mapearUsuario(credential.user)!;
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

  @override
  Future<AppUser> signInWithGoogle() async {
    if (!_googleSignInInicializado) {
      await GoogleSignIn.instance.initialize();
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
}
