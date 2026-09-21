import 'package:cloud_firestore/cloud_firestore.dart';

/// Calificación que una parte de un trato ya completado le deja a la otra.
/// El promedio/cantidad que se ven en el perfil público los recalcula
/// siempre el backend a partir de estos documentos — nunca los escribe el
/// cliente directamente (ver reglas de `users`/`perfiles_publicos`).
class Calificacion {
  const Calificacion({
    required this.id,
    required this.acuerdoId,
    required this.autorId,
    required this.destinatarioId,
    required this.puntaje,
    this.comentario,
    this.fecha,
  });

  final String id;
  final String acuerdoId;
  final String autorId;
  final String destinatarioId;

  /// De 1 a 5.
  final int puntaje;
  final String? comentario;
  final DateTime? fecha;

  factory Calificacion.fromFirestore(String id, Map<String, dynamic> data) {
    final fechaRaw = data['fecha'];
    return Calificacion(
      id: id,
      acuerdoId: data['acuerdoId'] as String? ?? '',
      autorId: data['autorId'] as String? ?? '',
      destinatarioId: data['destinatarioId'] as String? ?? '',
      puntaje: (data['puntaje'] as num?)?.toInt() ?? 0,
      comentario: data['comentario'] as String?,
      fecha: fechaRaw is Timestamp ? fechaRaw.toDate() : null,
    );
  }
}
