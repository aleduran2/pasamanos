import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/publicacion.dart';

abstract class PublicacionRepository {
  /// Genera un ID nuevo sin escribir nada todavía — se usa para subir las
  /// fotos a Storage bajo ese ID antes de crear el documento definitivo.
  String generarId();

  Future<void> guardar(Publicacion publicacion);

  Future<Publicacion?> obtenerPorId(String id);

  Future<List<Publicacion>> listarPorVendedor(String vendedorId);
}

class FirestorePublicacionRepository implements PublicacionRepository {
  FirestorePublicacionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _publicacionesRef =>
      _firestore.collection('publicaciones');

  @override
  String generarId() => _publicacionesRef.doc().id;

  @override
  Future<void> guardar(Publicacion publicacion) async {
    await _publicacionesRef.doc(publicacion.id).set({
      ...publicacion.toFirestore(),
      'fechaPublicacion': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Publicacion?> obtenerPorId(String id) async {
    final snapshot = await _publicacionesRef.doc(id).get();
    if (!snapshot.exists) return null;
    return Publicacion.fromFirestore(id, snapshot.data()!);
  }

  @override
  Future<List<Publicacion>> listarPorVendedor(String vendedorId) async {
    final snapshot = await _publicacionesRef
        .where('vendedorId', isEqualTo: vendedorId)
        .orderBy('fechaPublicacion', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Publicacion.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
