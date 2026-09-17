import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoConversacion {
  activa,
  cerrada;

  String get valorFirestore => name;

  static EstadoConversacion desdeFirestore(String valor) {
    return EstadoConversacion.values.firstWhere(
      (e) => e.name == valor,
      orElse: () => EstadoConversacion.activa,
    );
  }
}

class Conversacion {
  const Conversacion({
    required this.id,
    required this.publicacionId,
    required this.publicacionTitulo,
    required this.compradorId,
    required this.vendedorId,
    this.estado = EstadoConversacion.activa,
    this.ultimoMensaje,
    this.fechaUltimoMensaje,
  });

  final String id;
  final String publicacionId;
  final String publicacionTitulo;
  final String compradorId;
  final String vendedorId;
  final EstadoConversacion estado;
  final String? ultimoMensaje;
  final DateTime? fechaUltimoMensaje;

  Map<String, dynamic> toFirestore() {
    return {
      'publicacionId': publicacionId,
      'publicacionTitulo': publicacionTitulo,
      'compradorId': compradorId,
      'vendedorId': vendedorId,
      'participantes': [compradorId, vendedorId],
      'estado': estado.valorFirestore,
      'ultimoMensaje': ultimoMensaje,
    };
  }

  factory Conversacion.fromFirestore(String id, Map<String, dynamic> data) {
    final fechaRaw = data['fechaUltimoMensaje'];
    return Conversacion(
      id: id,
      publicacionId: data['publicacionId'] as String? ?? '',
      publicacionTitulo: data['publicacionTitulo'] as String? ?? '',
      compradorId: data['compradorId'] as String? ?? '',
      vendedorId: data['vendedorId'] as String? ?? '',
      estado: EstadoConversacion.desdeFirestore(
        data['estado'] as String? ?? 'activa',
      ),
      ultimoMensaje: data['ultimoMensaje'] as String?,
      fechaUltimoMensaje: fechaRaw is Timestamp ? fechaRaw.toDate() : null,
    );
  }
}
