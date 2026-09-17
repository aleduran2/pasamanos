import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoAcuerdo {
  activo,
  cancelado;

  String get valorFirestore => name;

  static EstadoAcuerdo desdeFirestore(String valor) {
    return EstadoAcuerdo.values.firstWhere(
      (e) => e.name == valor,
      orElse: () => EstadoAcuerdo.activo,
    );
  }
}

class Acuerdo {
  const Acuerdo({
    required this.id,
    required this.conversacionId,
    required this.publicacionId,
    required this.compradorId,
    required this.vendedorId,
    required this.precioAcordado,
    this.estado = EstadoAcuerdo.activo,
    this.fechaAcuerdo,
  });

  final String id;
  final String conversacionId;
  final String publicacionId;
  final String compradorId;
  final String vendedorId;
  final double precioAcordado;
  final EstadoAcuerdo estado;
  final DateTime? fechaAcuerdo;

  factory Acuerdo.fromFirestore(String id, Map<String, dynamic> data) {
    final fechaRaw = data['fechaAcuerdo'];
    return Acuerdo(
      id: id,
      conversacionId: data['conversacionId'] as String? ?? '',
      publicacionId: data['publicacionId'] as String? ?? '',
      compradorId: data['compradorId'] as String? ?? '',
      vendedorId: data['vendedorId'] as String? ?? '',
      precioAcordado: (data['precioAcordado'] as num?)?.toDouble() ?? 0,
      estado: EstadoAcuerdo.desdeFirestore(data['estado'] as String? ?? 'activo'),
      fechaAcuerdo: fechaRaw is Timestamp ? fechaRaw.toDate() : null,
    );
  }
}
