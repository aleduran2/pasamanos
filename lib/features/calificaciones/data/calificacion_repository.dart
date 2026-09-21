import 'package:cloud_firestore/cloud_firestore.dart';

abstract class CalificacionRepository {
  /// Si ya existe una calificación de `autorId` para este `acuerdoId`, no la
  /// pisa: la usaria ya se expresó sobre este trato una sola vez.
  Future<void> crear({
    required String acuerdoId,
    required String autorId,
    required String destinatarioId,
    required int puntaje,
    String? comentario,
  });

  Future<bool> yaCalifique({
    required String acuerdoId,
    required String autorId,
  });
}

class FirestoreCalificacionRepository implements CalificacionRepository {
  FirestoreCalificacionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('calificaciones');

  // El id determinístico (acuerdo + autora) es lo que impide, tanto acá
  // como en las reglas de Firestore, calificar dos veces el mismo trato.
  String _idPara(String acuerdoId, String autorId) => '${acuerdoId}_$autorId';

  @override
  Future<void> crear({
    required String acuerdoId,
    required String autorId,
    required String destinatarioId,
    required int puntaje,
    String? comentario,
  }) async {
    await _ref.doc(_idPara(acuerdoId, autorId)).set({
      'acuerdoId': acuerdoId,
      'autorId': autorId,
      'destinatarioId': destinatarioId,
      'puntaje': puntaje,
      'comentario': comentario,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> yaCalifique({
    required String acuerdoId,
    required String autorId,
  }) async {
    final snapshot = await _ref.doc(_idPara(acuerdoId, autorId)).get();
    return snapshot.exists;
  }
}
