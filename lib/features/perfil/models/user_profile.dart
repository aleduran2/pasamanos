import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoVerificacion {
  noVerificado,
  pendiente,
  verificado;

  String get valorFirestore => switch (this) {
    EstadoVerificacion.noVerificado => 'no_verificado',
    EstadoVerificacion.pendiente => 'pendiente',
    EstadoVerificacion.verificado => 'verificado',
  };

  static EstadoVerificacion desdeFirestore(String valor) {
    return switch (valor) {
      'pendiente' => EstadoVerificacion.pendiente,
      'verificado' => EstadoVerificacion.verificado,
      _ => EstadoVerificacion.noVerificado,
    };
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nombre,
    required this.email,
    this.fotoUrl,
    this.estadoVerificacion = EstadoVerificacion.noVerificado,
    this.calificacionPromedio = 0,
    this.cantidadTransacciones = 0,
    this.fechaRegistro,
  });

  final String uid;
  final String nombre;
  final String email;
  final String? fotoUrl;
  final EstadoVerificacion estadoVerificacion;
  final double calificacionPromedio;
  final int cantidadTransacciones;
  final DateTime? fechaRegistro;

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'email': email,
      'fotoUrl': fotoUrl,
      'estadoVerificacion': estadoVerificacion.valorFirestore,
      'calificacionPromedio': calificacionPromedio,
      'cantidadTransacciones': cantidadTransacciones,
    };
  }

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    final fechaRegistroRaw = data['fechaRegistro'];
    return UserProfile(
      uid: uid,
      nombre: data['nombre'] as String? ?? '',
      email: data['email'] as String? ?? '',
      fotoUrl: data['fotoUrl'] as String?,
      estadoVerificacion: EstadoVerificacion.desdeFirestore(
        data['estadoVerificacion'] as String? ?? 'no_verificado',
      ),
      calificacionPromedio:
          (data['calificacionPromedio'] as num?)?.toDouble() ?? 0,
      cantidadTransacciones: (data['cantidadTransacciones'] as num?)?.toInt() ?? 0,
      fechaRegistro: fechaRegistroRaw is Timestamp
          ? fechaRegistroRaw.toDate()
          : null,
    );
  }
}
