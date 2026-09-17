import 'package:cloud_firestore/cloud_firestore.dart';

import '../../catalogo/models/publicacion.dart';
import '../../chat/models/mensaje.dart';
import '../models/acuerdo.dart';

/// Se lanza cuando alguien intenta cerrar un acuerdo sobre una publicación
/// que ya no está disponible (otro comprador se la llevó primero).
class PublicacionNoDisponibleException implements Exception {}

abstract class AcuerdoRepository {
  /// Crea el acuerdo y marca la publicación como reservada en una sola
  /// transacción: si la publicación ya no está disponible, no se crea nada
  /// y se lanza [PublicacionNoDisponibleException].
  Future<Acuerdo> cerrarAcuerdo({
    required String conversacionId,
    required String publicacionId,
    required String compradorId,
    required String vendedorId,
    required double precioAcordado,
  });

  Future<Acuerdo?> obtenerPorConversacion(String conversacionId);
}

class FirestoreAcuerdoRepository implements AcuerdoRepository {
  FirestoreAcuerdoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _acuerdosRef =>
      _firestore.collection('acuerdos');

  CollectionReference<Map<String, dynamic>> get _publicacionesRef =>
      _firestore.collection('publicaciones');

  CollectionReference<Map<String, dynamic>> get _conversacionesRef =>
      _firestore.collection('conversaciones');

  @override
  Future<Acuerdo> cerrarAcuerdo({
    required String conversacionId,
    required String publicacionId,
    required String compradorId,
    required String vendedorId,
    required double precioAcordado,
  }) async {
    final acuerdoRef = _acuerdosRef.doc();
    final publicacionRef = _publicacionesRef.doc(publicacionId);

    await _firestore.runTransaction((transaction) async {
      final publicacionSnap = await transaction.get(publicacionRef);
      final estadoActual = publicacionSnap.data()?['estado'] as String?;
      if (estadoActual != EstadoPublicacion.disponible.valorFirestore) {
        throw PublicacionNoDisponibleException();
      }

      transaction.update(publicacionRef, {
        'estado': EstadoPublicacion.reservado.valorFirestore,
      });
      transaction.set(acuerdoRef, {
        'conversacionId': conversacionId,
        'publicacionId': publicacionId,
        'compradorId': compradorId,
        'vendedorId': vendedorId,
        'precioAcordado': precioAcordado,
        'estado': EstadoAcuerdo.activo.valorFirestore,
        'fechaAcuerdo': FieldValue.serverTimestamp(),
      });
    });

    final textoSistema =
        'Trato cerrado por \$${precioAcordado.toStringAsFixed(0)}.';
    final conversacionRef = _conversacionesRef.doc(conversacionId);
    await conversacionRef.collection('mensajes').add({
      'emisorId': vendedorId,
      'texto': textoSistema,
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
      'tipo': TipoMensaje.sistema.valorFirestore,
    });
    await conversacionRef.update({
      'ultimoMensaje': textoSistema,
      'fechaUltimoMensaje': FieldValue.serverTimestamp(),
    });

    final acuerdoSnap = await acuerdoRef.get();
    return Acuerdo.fromFirestore(acuerdoRef.id, acuerdoSnap.data()!);
  }

  @override
  Future<Acuerdo?> obtenerPorConversacion(String conversacionId) async {
    final snapshot = await _acuerdosRef
        .where('conversacionId', isEqualTo: conversacionId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Acuerdo.fromFirestore(doc.id, doc.data());
  }
}
