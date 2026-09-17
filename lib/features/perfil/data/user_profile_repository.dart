import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> obtenerPorId(String uid);

  /// Crea el perfil solo si todavía no existe (primer login/registro).
  /// No pisa datos existentes si el usuario ya tenía perfil.
  Future<UserProfile> crearSiNoExiste({
    required String uid,
    required String nombre,
    required String email,
    String? fotoUrl,
  });
}

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  @override
  Future<UserProfile?> obtenerPorId(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromFirestore(uid, snapshot.data()!);
  }

  @override
  Future<UserProfile> crearSiNoExiste({
    required String uid,
    required String nombre,
    required String email,
    String? fotoUrl,
  }) async {
    final docRef = _usersRef.doc(uid);
    final existente = await docRef.get();
    if (existente.exists) {
      return UserProfile.fromFirestore(uid, existente.data()!);
    }

    final perfil = UserProfile(
      uid: uid,
      nombre: nombre,
      email: email,
      fotoUrl: fotoUrl,
    );
    await docRef.set({
      ...perfil.toFirestore(),
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
    return perfil;
  }
}
