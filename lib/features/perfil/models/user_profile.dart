import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoVerificacion {
  noVerificado,
  pendiente,
  verificado,
  rechazado;

  String get valorFirestore => switch (this) {
    EstadoVerificacion.noVerificado => 'no_verificado',
    EstadoVerificacion.pendiente => 'pendiente',
    EstadoVerificacion.verificado => 'verificado',
    EstadoVerificacion.rechazado => 'rechazado',
  };

  static EstadoVerificacion desdeFirestore(String valor) {
    return switch (valor) {
      'pendiente' => EstadoVerificacion.pendiente,
      'verificado' => EstadoVerificacion.verificado,
      'rechazado' => EstadoVerificacion.rechazado,
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
    this.telefono,
    this.estadoVerificacion = EstadoVerificacion.noVerificado,
    this.calificacionPromedio = 0,
    this.cantidadTransacciones = 0,
    this.fechaRegistro,
    this.kycSessionId,
    this.notificacionesActivas = true,
  });

  final String uid;
  final String nombre;
  final String email;
  final String? fotoUrl;

  /// Número de WhatsApp, cargado por la propia dueña del perfil desde "Mi
  /// perfil". Nunca se comparte automáticamente: recién se expone a la otra
  /// parte de un trato cuando ella misma elige compartirlo en el chat (ver
  /// [[chat_screen]]), y solo para ese trato puntual.
  final String? telefono;
  final EstadoVerificacion estadoVerificacion;
  final double calificacionPromedio;
  final int cantidadTransacciones;
  final DateTime? fechaRegistro;

  /// Referencia de la sesión de verificación de identidad (Didit) — solo
  /// un id opaco, no datos personales. Lo escribe únicamente el backend.
  final String? kycSessionId;

  /// Preferencia propia de la usuaria, independiente del permiso del
  /// sistema operativo: Android no deja que una app "revoque" un permiso
  /// ya otorgado, así que apagar esto es lo que realmente controla si le
  /// llegan notificaciones — se logra borrando sus tokens de FCM (ver
  /// [[fcm_token_service]]), no tocando el permiso en sí.
  final bool notificacionesActivas;

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'email': email,
      'fotoUrl': fotoUrl,
      'telefono': telefono,
      'estadoVerificacion': estadoVerificacion.valorFirestore,
      'calificacionPromedio': calificacionPromedio,
      'cantidadTransacciones': cantidadTransacciones,
      'notificacionesActivas': notificacionesActivas,
    };
  }

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    final fechaRegistroRaw = data['fechaRegistro'];
    return UserProfile(
      uid: uid,
      nombre: data['nombre'] as String? ?? '',
      email: data['email'] as String? ?? '',
      fotoUrl: data['fotoUrl'] as String?,
      telefono: data['telefono'] as String?,
      estadoVerificacion: EstadoVerificacion.desdeFirestore(
        data['estadoVerificacion'] as String? ?? 'no_verificado',
      ),
      calificacionPromedio:
          (data['calificacionPromedio'] as num?)?.toDouble() ?? 0,
      cantidadTransacciones: (data['cantidadTransacciones'] as num?)?.toInt() ?? 0,
      fechaRegistro: fechaRegistroRaw is Timestamp
          ? fechaRegistroRaw.toDate()
          : null,
      kycSessionId: data['kycSessionId'] as String?,
      notificacionesActivas: data['notificacionesActivas'] as bool? ?? true,
    );
  }
}
