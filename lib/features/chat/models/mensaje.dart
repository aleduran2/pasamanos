import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoMensaje {
  texto,
  sistema;

  String get valorFirestore => name;

  static TipoMensaje desdeFirestore(String valor) {
    return TipoMensaje.values.firstWhere(
      (t) => t.name == valor,
      orElse: () => TipoMensaje.texto,
    );
  }
}

class Mensaje {
  const Mensaje({
    required this.id,
    required this.emisorId,
    required this.texto,
    this.tipo = TipoMensaje.texto,
    this.leido = false,
    this.timestamp,
  });

  final String id;
  final String emisorId;
  final String texto;
  final TipoMensaje tipo;
  final bool leido;
  final DateTime? timestamp;

  factory Mensaje.fromFirestore(String id, Map<String, dynamic> data) {
    final timestampRaw = data['timestamp'];
    return Mensaje(
      id: id,
      emisorId: data['emisorId'] as String? ?? '',
      texto: data['texto'] as String? ?? '',
      tipo: TipoMensaje.desdeFirestore(data['tipo'] as String? ?? 'texto'),
      leido: data['leido'] as bool? ?? false,
      timestamp: timestampRaw is Timestamp ? timestampRaw.toDate() : null,
    );
  }
}
