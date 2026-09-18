import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Muestra notificaciones locales cuando llega un mensaje de FCM con la app
/// en primer plano — Android no las muestra solo por sí mismo en ese caso.
class LocalNotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _canalId = 'mensajes';
  static const _canalNombre = 'Mensajes';

  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;

    const configuracionAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: configuracionAndroid),
    );

    const canal = AndroidNotificationChannel(
      _canalId,
      _canalNombre,
      description: 'Nuevos mensajes y tratos cerrados',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(canal);
  }

  Future<void> mostrar({required String titulo, required String cuerpo}) {
    const detalleAndroid = AndroidNotificationDetails(
      _canalId,
      _canalNombre,
      importance: Importance.high,
      priority: Priority.high,
    );
    return _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: titulo,
      body: cuerpo,
      notificationDetails: const NotificationDetails(android: detalleAndroid),
    );
  }
}
