import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/perfil_publico.dart';

abstract class PerfilPublicoRepository {
  Future<PerfilPublico?> obtenerPorId(String uid);
}

class FirestorePerfilPublicoRepository implements PerfilPublicoRepository {
  FirestorePerfilPublicoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('perfiles_publicos');

  @override
  Future<PerfilPublico?> obtenerPorId(String uid) async {
    final snapshot = await _ref.doc(uid).get();
    if (!snapshot.exists) return null;
    return PerfilPublico.fromFirestore(uid, snapshot.data()!);
  }
}
