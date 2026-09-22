import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notification_service.dart';

abstract class FcmTokenService {
  /// Pide permiso de notificaciones solo si todavía no se decidió nada
  /// (primera vez), guarda el token FCM de este dispositivo en el perfil
  /// del usuario y deja armado el aviso local para cuando llegue un
  /// mensaje con la app en primer plano.
  Future<void> registrarToken(String uid);

  /// Estado actual del permiso de notificaciones, para mostrarlo en "Mi
  /// perfil".
  Future<AuthorizationStatus> obtenerEstadoPermiso();

  /// Vuelve a pedir el permiso — a diferencia de `registrarToken`, esto se
  /// llama siempre que la usuaria lo pide explícitamente desde "Mi
  /// perfil", sin importar si ya se había decidido antes. Si el sistema
  /// operativo ya lo denegó de forma permanente, no va a mostrar ningún
  /// cartel (limitación del sistema, no de la app) — por eso el estado
  /// resultante puede seguir siendo "denegado".
  Future<AuthorizationStatus> pedirPermiso();

  /// Borra los tokens de FCM guardados: Android no deja que una app
  /// "retire" un permiso ya otorgado, así que esta es la única forma real
  /// de que dejen de llegarle notificaciones — sin token, el backend no
  /// tiene a dónde mandarlas.
  Future<void> desactivar(String uid);
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
    // Si la usuaria las apagó desde "Mi perfil", este método se sigue
    // llamando solo en cada login (ver HomeScreen) — sin este chequeo,
    // volvería a guardar el token y reactivarlas sin que ella lo pidiera.
    final perfilSnap = await _firestore.collection('users').doc(uid).get();
    final notificacionesActivas =
        perfilSnap.data()?['notificacionesActivas'] as bool? ?? true;
    if (!notificacionesActivas) return;

    // Solo se pregunta la primera vez: una vez que el sistema operativo ya
    // tiene una respuesta (autorizado o denegado), volver a llamar acá en
    // cada login no debería insistir con el cartel — por eso se chequea
    // el estado actual antes de pedir permiso.
    final configuracionActual = await _messaging.getNotificationSettings();
    if (configuracionActual.authorizationStatus ==
        AuthorizationStatus.notDetermined) {
      await _messaging.requestPermission();
    }
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

  @override
  Future<AuthorizationStatus> obtenerEstadoPermiso() async {
    final configuracion = await _messaging.getNotificationSettings();
    return configuracion.authorizationStatus;
  }

  @override
  Future<AuthorizationStatus> pedirPermiso() async {
    final configuracion = await _messaging.requestPermission();
    return configuracion.authorizationStatus;
  }

  @override
  Future<void> desactivar(String uid) async {
    await _firestore.collection('users').doc(uid).update({'fcmTokens': []});
  }
}
