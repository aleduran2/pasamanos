import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notification_service.dart';

abstract class FcmTokenService {
  /// Pide permiso de notificaciones (si hace falta), guarda el token FCM de
  /// este dispositivo en el perfil del usuario y deja armado el aviso local
  /// para cuando llegue un mensaje con la app en primer plano.
  Future<void> registrarToken(String uid);
}

class FirebaseFcmTokenService implements FcmTokenService {
  FirebaseFcmTokenService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    LocalNotificationService? notificaciones,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _notificaciones = notificaciones ?? LocalNotificationService();

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final LocalNotificationService _notificaciones;

  @override
  Future<void> registrarToken(String uid) async {
    await _messaging.requestPermission();
    await _notificaciones.inicializar();

    final token = await _messaging.getToken();
    if (token != null) {
      await _guardarToken(uid, token);
    }

    _messaging.onTokenRefresh.listen((nuevoToken) {
      _guardarToken(uid, nuevoToken);
    });

    FirebaseMessaging.onMessage.listen((mensaje) {
      final notificacion = mensaje.notification;
      if (notificacion == null) return;
      _notificaciones.mostrar(
        titulo: notificacion.title ?? 'Pasamanos',
        cuerpo: notificacion.body ?? '',
      );
    });
  }

  Future<void> _guardarToken(String uid, String token) {
    return _firestore.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }
}
