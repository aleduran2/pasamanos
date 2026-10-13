class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.nombre,
    this.fotoUrl,
    this.emailVerificado = false,
  });

  final String uid;
  final String email;
  final String? nombre;
  final String? fotoUrl;

  /// Si confirmó el mail que puso al registrarse (clickeando el link que
  /// le mandamos). Con Google siempre viene en `true` — Google ya
  /// verificó esa dirección antes de dejarla usar como cuenta.
  final bool emailVerificado;
}
