/// Recorte público del perfil de una usuaria: lo único que cualquier otra
/// persona autenticada puede leer de ella (para mostrar su reputación en
/// una publicación), a diferencia de `users/{uid}` que solo lee su dueña.
class PerfilPublico {
  const PerfilPublico({
    required this.uid,
    required this.nombre,
    this.fotoUrl,
    this.calificacionPromedio = 0,
    this.cantidadTransacciones = 0,
  });

  final String uid;
  final String nombre;
  final String? fotoUrl;
  final double calificacionPromedio;
  final int cantidadTransacciones;

  factory PerfilPublico.fromFirestore(String uid, Map<String, dynamic> data) {
    return PerfilPublico(
      uid: uid,
      nombre: data['nombre'] as String? ?? '',
      fotoUrl: data['fotoUrl'] as String?,
      calificacionPromedio:
          (data['calificacionPromedio'] as num?)?.toDouble() ?? 0,
      cantidadTransacciones: (data['cantidadTransacciones'] as num?)?.toInt() ?? 0,
    );
  }
}
