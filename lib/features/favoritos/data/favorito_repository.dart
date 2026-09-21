import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FavoritoRepository {
  /// Guarda o quita una publicación de favoritos de esa usuaria.
  Future<void> marcar({
    required String uid,
    required String publicacionId,
    required bool favorito,
  });

  Future<bool> esFavorito({required String uid, required String publicacionId});

  /// IDs de publicaciones favoritas, más recientes primero.
  Stream<List<String>> idsFavoritos(String uid);
}

class FirestoreFavoritoRepository implements FavoritoRepository {
  FirestoreFavoritoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _favoritosRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('favoritos');

  @override
  Future<void> marcar({
    required String uid,
    required String publicacionId,
    required bool favorito,
  }) async {
    final doc = _favoritosRef(uid).doc(publicacionId);
    if (favorito) {
      await doc.set({'fecha': FieldValue.serverTimestamp()});
    } else {
      await doc.delete();
    }
  }

  @override
  Future<bool> esFavorito({
    required String uid,
    required String publicacionId,
  }) async {
    final doc = await _favoritosRef(uid).doc(publicacionId).get();
    return doc.exists;
  }

  @override
  Stream<List<String>> idsFavoritos(String uid) {
    return _favoritosRef(
      uid,
    ).orderBy('fecha', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.id).toList(),
    );
  }
}
