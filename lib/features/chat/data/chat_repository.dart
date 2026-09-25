import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversacion.dart';
import '../models/mensaje.dart';

const _textoBienvenida =
    'Coordiná todo acá dentro: cuando se pongan de acuerdo en el precio, '
    'cierren el trato. Después la compradora elige cómo seguir: pagar con '
    'Mercado Pago (identidad verificada y pago protegido) o coordinar '
    'directo por WhatsApp, sin costo. Cualquiera de los dos habilita '
    'compartir WhatsApp para la entrega.';

abstract class ChatRepository {
  /// Devuelve la conversación entre comprador y vendedor sobre esa
  /// publicación, creándola si todavía no existe. El ID es determinístico
  /// (publicacionId + compradorId) para no duplicar conversaciones.
  Future<Conversacion> obtenerOCrear({
    required String publicacionId,
    required String publicacionTitulo,
    required String compradorId,
    required String vendedorId,
  });

  Stream<List<Conversacion>> misConversaciones(String uid);

  Stream<List<Mensaje>> mensajes(String conversacionId);

  Future<void> enviarMensaje({
    required String conversacionId,
    required String emisorId,
    required String texto,
    TipoMensaje tipo = TipoMensaje.texto,
  });

  /// Marca la conversación como vista por esta persona (para que deje de
  /// mostrarse como "no leída" en la lista de conversaciones).
  Future<void> marcarComoLeido(String conversacionId, String uid);
}

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _conversacionesRef =>
      _firestore.collection('conversaciones');

  @override
  Future<Conversacion> obtenerOCrear({
    required String publicacionId,
    required String publicacionTitulo,
    required String compradorId,
    required String vendedorId,
  }) async {
    final id = '${publicacionId}_$compradorId';
    final docRef = _conversacionesRef.doc(id);
    final existente = await docRef.get();
    if (existente.exists) {
      return Conversacion.fromFirestore(id, existente.data()!);
    }

    final conversacion = Conversacion(
      id: id,
      publicacionId: publicacionId,
      publicacionTitulo: publicacionTitulo,
      compradorId: compradorId,
      vendedorId: vendedorId,
    );
    await docRef.set(conversacion.toFirestore());
    // El emisor tiene que ser quien hace este write (la compradora, única
    // que puede estar creando la conversación en este punto) — las reglas
    // de Firestore exigen que emisorId coincida con quien escribe. No
    // importa para la UI: un mensaje "sistema" se muestra igual sin
    // mostrar de quién es.
    await docRef.collection('mensajes').add({
      'emisorId': compradorId,
      'texto': _textoBienvenida,
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
      'tipo': TipoMensaje.sistema.valorFirestore,
    });
    return conversacion;
  }

  @override
  Stream<List<Conversacion>> misConversaciones(String uid) {
    return _conversacionesRef
        .where('participantes', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final conversaciones = snapshot.docs
              .map((doc) => Conversacion.fromFirestore(doc.id, doc.data()))
              .toList();
          conversaciones.sort((a, b) {
            final fechaA = a.fechaUltimoMensaje;
            final fechaB = b.fechaUltimoMensaje;
            if (fechaA == null && fechaB == null) return 0;
            if (fechaA == null) return 1;
            if (fechaB == null) return -1;
            return fechaB.compareTo(fechaA);
          });
          return conversaciones;
        });
  }

  @override
  Stream<List<Mensaje>> mensajes(String conversacionId) {
    return _conversacionesRef
        .doc(conversacionId)
        .collection('mensajes')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Mensaje.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> enviarMensaje({
    required String conversacionId,
    required String emisorId,
    required String texto,
    TipoMensaje tipo = TipoMensaje.texto,
  }) async {
    final conversacionRef = _conversacionesRef.doc(conversacionId);
    final mensajeRef = conversacionRef.collection('mensajes').doc();

    final batch = _firestore.batch();
    batch.set(mensajeRef, {
      'emisorId': emisorId,
      'texto': texto,
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
      'tipo': tipo.valorFirestore,
    });
    batch.update(conversacionRef, {
      'ultimoMensaje': texto,
      'ultimoMensajeEmisorId': emisorId,
      'fechaUltimoMensaje': FieldValue.serverTimestamp(),
      'leidoPor': [emisorId],
    });
    await batch.commit();
  }

  @override
  Future<void> marcarComoLeido(String conversacionId, String uid) async {
    await _conversacionesRef.doc(conversacionId).update({
      'leidoPor': FieldValue.arrayUnion([uid]),
    });
  }
}
