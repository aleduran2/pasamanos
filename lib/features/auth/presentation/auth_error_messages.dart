import 'package:firebase_auth/firebase_auth.dart';

String mensajeErrorAuth(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'El email no es válido.',
      'user-disabled' => 'Esta cuenta fue deshabilitada.',
      'user-not-found' => 'No existe una cuenta con ese email.',
      'wrong-password' => 'La contraseña es incorrecta.',
      'invalid-credential' => 'Email o contraseña incorrectos.',
      'email-already-in-use' => 'Ya existe una cuenta con ese email.',
      'weak-password' => 'La contraseña es demasiado débil.',
      'network-request-failed' => 'No hay conexión a internet.',
      'too-many-requests' => 'Demasiados intentos. Probá de nuevo en unos minutos.',
      _ => 'Ocurrió un error. Intentá de nuevo.',
    };
  }
  return 'Ocurrió un error. Intentá de nuevo.';
}
