import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/formato.dart';
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

  /// Igual que [obtenerPorConversacion] pero en tiempo real — así el chat
  /// refleja sin recargar la pantalla los cambios que llegan de otro lado
  /// (el webhook de Mercado Pago actualizando `estadoPago`, o que la otra
  /// persona cierre el trato mientras ya se tenía el chat abierto).
  Stream<Acuerdo?> observarPorConversacion(
    String conversacionId, {
    required String miUid,
  });

  /// Cierra la venta: la publicación pasa a "vendido" y el acuerdo activo
  /// (si hay uno) a "completado". Avisa en la conversación del acuerdo.
  /// `miUid` (la vendedora) es necesario para que la query de lista que
  /// busca ese acuerdo pase las reglas de Firestore (ver firestore.rules).
  Future<void> marcarVendido(String publicacionId, {required String miUid});

  /// Deshace la reserva: la publicación vuelve a "disponible" para otras
  /// compradoras y el acuerdo activo (si hay uno) queda "cancelado". Avisa
  /// en la conversación del acuerdo.
  Future<void> cancelarReserva(String publicacionId, {required String miUid});

  /// Comparte el WhatsApp de quien llama para este trato puntual. Escribe
  /// únicamente el campo propio (`telefonoComprador` o `telefonoVendedor`
  /// según corresponda) — reforzado también en las reglas de Firestore. Deja
  /// además un aviso en la conversación (la otra parte recibe push como con
  /// cualquier mensaje nuevo).
  Future<void> compartirTelefono({
    required String acuerdoId,
    required String conversacionId,
    required bool esComprador,
    required String emisorId,
    required String telefono,
  });

  /// La compradora elige coordinar la entrega directo por WhatsApp, sin
  /// pasar por Mercado Pago — no hay vuelta atrás una vez elegido (lo
  /// refuerzan las reglas de Firestore).
  Future<void> elegirTratoDirecto({
    required String acuerdoId,
    required String conversacionId,
    required String compradorId,
  });
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
        // Necesario para que las reglas de Firestore puedan validar una
        // query de lista (ver comentario en firestore.rules) — sin esto,
        // ni la propia compradora/vendedora puede leer el acuerdo desde
        // la query por conversación.
        'participantes': [compradorId, vendedorId],
        'precioAcordado': precioAcordado,
        'estado': EstadoAcuerdo.activo.valorFirestore,
        'fechaAcuerdo': FieldValue.serverTimestamp(),
        'coordinacionDirecta': false,
      });
    });

    final textoSistema =
        'Trato cerrado por ${formatearPrecio(precioAcordado)}.';
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
      'ultimoMensajeEmisorId': vendedorId,
      'fechaUltimoMensaje': FieldValue.serverTimestamp(),
      'leidoPor': [vendedorId],
    });

    final acuerdoSnap = await acuerdoRef.get();
    return Acuerdo.fromFirestore(acuerdoRef.id, acuerdoSnap.data()!);
  }

  @override
  Future<Acuerdo?> obtenerPorConversacion(String conversacionId) async {
    // orderBy + limit(1) es necesario: si la conversación tuvo un acuerdo
    // cancelado y después se volvió a cerrar el trato, hay más de un
    // documento con este mismo conversacionId (cada `cerrarAcuerdo` crea
    // uno nuevo) — sin orden explícito, Firestore podría devolver
    // cualquiera de los dos, no necesariamente el vigente.
    final snapshot = await _acuerdosRef
        .where('conversacionId', isEqualTo: conversacionId)
        .orderBy('fechaAcuerdo', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Acuerdo.fromFirestore(doc.id, doc.data());
  }

  @override
  Stream<Acuerdo?> observarPorConversacion(
    String conversacionId, {
    required String miUid,
  }) {
    // orderBy + limit(1): mismo motivo que en obtenerPorConversacion — si
    // la conversación tuvo un acuerdo cancelado y se volvió a cerrar el
    // trato, puede haber más de un documento para este conversacionId.
    return _acuerdosRef
        .where('conversacionId', isEqualTo: conversacionId)
        .where('participantes', arrayContains: miUid)
        .orderBy('fechaAcuerdo', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return Acuerdo.fromFirestore(doc.id, doc.data());
        });
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _acuerdoActivoPara(
    String publicacionId,
    String miUid,
  ) async {
    final snapshot = await _acuerdosRef
        .where('publicacionId', isEqualTo: publicacionId)
        .where('estado', isEqualTo: EstadoAcuerdo.activo.valorFirestore)
        .where('participantes', arrayContains: miUid)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first;
  }

  Future<void> _avisarEnConversacion(
    String conversacionId,
    String texto, {
    String? emisorId,
  }) async {
    final conversacionRef = _conversacionesRef.doc(conversacionId);
    var emisor = emisorId;
    if (emisor == null) {
      final conversacionSnap = await conversacionRef.get();
      emisor = conversacionSnap.data()?['vendedorId'] as String? ?? '';
    }
    await conversacionRef.collection('mensajes').add({
      'emisorId': emisor,
      'texto': texto,
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
      'tipo': TipoMensaje.sistema.valorFirestore,
    });
    await conversacionRef.update({
      'ultimoMensaje': texto,
      'ultimoMensajeEmisorId': emisor,
      'fechaUltimoMensaje': FieldValue.serverTimestamp(),
      'leidoPor': [emisor],
    });
  }

  @override
  Future<void> marcarVendido(String publicacionId, {required String miUid}) async {
    final acuerdoDoc = await _acuerdoActivoPara(publicacionId, miUid);
    await _firestore.runTransaction((transaction) async {
      if (acuerdoDoc != null) {
        transaction.update(_acuerdosRef.doc(acuerdoDoc.id), {
          'estado': EstadoAcuerdo.completado.valorFirestore,
        });
      }
      transaction.update(_publicacionesRef.doc(publicacionId), {
        'estado': EstadoPublicacion.vendido.valorFirestore,
      });
    });
    if (acuerdoDoc != null) {
      final conversacionId = acuerdoDoc.data()['conversacionId'] as String?;
      if (conversacionId != null) {
        await _avisarEnConversacion(
          conversacionId,
          'La vendedora marcó esta publicación como vendida.',
        );
      }
    }
  }

  @override
  Future<void> cancelarReserva(String publicacionId, {required String miUid}) async {
    final acuerdoDoc = await _acuerdoActivoPara(publicacionId, miUid);
    await _firestore.runTransaction((transaction) async {
      if (acuerdoDoc != null) {
        transaction.update(_acuerdosRef.doc(acuerdoDoc.id), {
          'estado': EstadoAcuerdo.cancelado.valorFirestore,
        });
      }
      transaction.update(_publicacionesRef.doc(publicacionId), {
        'estado': EstadoPublicacion.disponible.valorFirestore,
      });
    });
    if (acuerdoDoc != null) {
      final conversacionId = acuerdoDoc.data()['conversacionId'] as String?;
      if (conversacionId != null) {
        await _avisarEnConversacion(
          conversacionId,
          'La reserva se canceló. La publicación vuelve a estar disponible.',
        );
      }
    }
  }

  @override
  Future<void> compartirTelefono({
    required String acuerdoId,
    required String conversacionId,
    required bool esComprador,
    required String emisorId,
    required String telefono,
  }) async {
    await _acuerdosRef.doc(acuerdoId).update({
      esComprador ? 'telefonoComprador' : 'telefonoVendedor': telefono,
    });
    await _avisarEnConversacion(
      conversacionId,
      'Compartió su WhatsApp para coordinar la entrega.',
      emisorId: emisorId,
    );
  }

  @override
  Future<void> elegirTratoDirecto({
    required String acuerdoId,
    required String conversacionId,
    required String compradorId,
  }) async {
    await _acuerdosRef.doc(acuerdoId).update({'coordinacionDirecta': true});
    await _avisarEnConversacion(
      conversacionId,
      'La compradora eligió coordinar directo por WhatsApp, sin pago '
      'dentro de la app.',
      emisorId: compradorId,
    );
  }
}
