class AppUser {
  const AppUser({required this.uid, required this.email, this.nombre, this.fotoUrl});

  final String uid;
  final String email;
  final String? nombre;
  final String? fotoUrl;
}
