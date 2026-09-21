import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoAcuerdo {
  activo,
  completado,
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
    this.preferenceId,
    this.estadoPago,
    this.pagoId,
    this.telefonoComprador,
    this.telefonoVendedor,
  });

  final String id;
  final String conversacionId;
  final String publicacionId;
  final String compradorId;
  final String vendedorId;
  final double precioAcordado;
  final EstadoAcuerdo estado;
  final DateTime? fechaAcuerdo;

  /// Estos tres los escribe únicamente el backend (Cloud Functions), nunca
  /// el cliente: `preferenceId` al crear el link de pago, `estadoPago`/
  /// `pagoId` cuando llega la confirmación de Mercado Pago (approved /
  /// pending / rejected / etc., tal cual lo informa MP).
  final String? preferenceId;
  final String? estadoPago;
  final String? pagoId;

  /// WhatsApp que cada parte eligió compartir para ESTE trato puntual (no
  /// es el mismo campo que el perfil general: acá vive solo mientras dura
  /// el acuerdo, y cada quien únicamente puede escribir el suyo propio —
  /// reforzado en las reglas de Firestore).
  final String? telefonoComprador;
  final String? telefonoVendedor;

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
      preferenceId: data['preferenceId'] as String?,
      estadoPago: data['estadoPago'] as String?,
      pagoId: data['pagoId'] as String?,
      telefonoComprador: data['telefonoComprador'] as String?,
      telefonoVendedor: data['telefonoVendedor'] as String?,
    );
  }
}
