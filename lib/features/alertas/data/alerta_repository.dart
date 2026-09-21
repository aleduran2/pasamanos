import 'package:cloud_firestore/cloud_firestore.dart';

import '../../catalogo/models/publicacion.dart';
import '../models/alerta.dart';

abstract class AlertaRepository {
  /// Id determinístico (uid + categoría + talle): crear la misma alerta
  /// dos veces no duplica la fila ni, más importante, el aviso por push.
  Future<void> crear({
    required String uid,
    required Categoria categoria,
    required String talle,
  });

  Future<void> eliminar(String id);

  Stream<List<Alerta>> misAlertas(String uid);
}

class FirestoreAlertaRepository implements AlertaRepository {
  FirestoreAlertaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('alertas');

  String _idPara(String uid, Categoria categoria, String talle) {
    final talleSanitizado = talle.replaceAll('/', '-');
    return '${uid}_${categoria.name}_$talleSanitizado';
  }

  @override
  Future<void> crear({
    required String uid,
    required Categoria categoria,
    required String talle,
  }) async {
    final id = _idPara(uid, categoria, talle);
    await _ref.doc(id).set({
      'uid': uid,
      'categoria': categoria.valorFirestore,
      'talle': talle,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> eliminar(String id) async {
    await _ref.doc(id).delete();
  }

  @override
  Stream<List<Alerta>> misAlertas(String uid) {
    return _ref.where('uid', isEqualTo: uid).snapshots().map((snapshot) {
      final alertas = snapshot.docs
          .map((doc) => Alerta.fromFirestore(doc.id, doc.data()))
          .toList();
      alertas.sort((a, b) {
        final fechaA = a.fechaCreacion;
        final fechaB = b.fechaCreacion;
        if (fechaA == null && fechaB == null) return 0;
        if (fechaA == null) return -1;
        if (fechaB == null) return 1;
        return fechaB.compareTo(fechaA);
      });
      return alertas;
    });
  }
}
