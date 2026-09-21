import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> obtenerPorId(String uid);

  /// Crea el perfil solo si todavía no existe (primer login/registro).
  /// No pisa datos existentes si el usuario ya tenía perfil.
  Future<UserProfile> crearSiNoExiste({
    required String uid,
    required String nombre,
    required String email,
    String? fotoUrl,
  });

  /// Guarda el número de WhatsApp que la propia usuaria cargó en su perfil.
  Future<void> actualizarTelefono({
    required String uid,
    required String telefono,
  });

  /// Cambia el nombre visible, tanto en `users` como en la copia pública
  /// (`perfiles_publicos`) que ve el resto de la comunidad.
  Future<void> actualizarNombre({required String uid, required String nombre});

  /// Cambia la foto de perfil, igual que el nombre: en `users` y en la
  /// copia pública.
  Future<void> actualizarFoto({required String uid, required String fotoUrl});
}

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _perfilesPublicosRef =>
      _firestore.collection('perfiles_publicos');

  @override
  Future<UserProfile?> obtenerPorId(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromFirestore(uid, snapshot.data()!);
  }

  @override
  Future<UserProfile> crearSiNoExiste({
    required String uid,
    required String nombre,
    required String email,
    String? fotoUrl,
  }) async {
    final docRef = _usersRef.doc(uid);
    final existente = await docRef.get();
    if (existente.exists) {
      // Cuentas de antes de que existiera `perfiles_publicos` (o antes de
      // que se guardara el teléfono) no tienen por qué tener ya esta copia
      // — se asegura acá, sin pisar una que ya esté, para que la
      // reputación funcione también con usuarias ya registradas.
      await _asegurarPerfilPublico(uid, existente.data()!);
      return UserProfile.fromFirestore(uid, existente.data()!);
    }

    final perfil = UserProfile(
      uid: uid,
      nombre: nombre,
      email: email,
      fotoUrl: fotoUrl,
    );
    await docRef.set({
      ...perfil.toFirestore(),
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
    await _perfilesPublicosRef.doc(uid).set({
      'nombre': nombre,
      'fotoUrl': fotoUrl,
      'calificacionPromedio': 0,
      'cantidadTransacciones': 0,
    });
    return perfil;
  }

  // Copia pública mínima: es lo único de otra usuaria que el resto de la
  // app puede leer (para mostrar su calificación en una publicación), así
  // que acá no va nada más que nombre/foto/reputación.
  Future<void> _asegurarPerfilPublico(
    String uid,
    Map<String, dynamic> datosUsuario,
  ) async {
    final publicoRef = _perfilesPublicosRef.doc(uid);
    final existentePublico = await publicoRef.get();
    if (existentePublico.exists) return;
    await publicoRef.set({
      'nombre': datosUsuario['nombre'] as String? ?? '',
      'fotoUrl': datosUsuario['fotoUrl'] as String?,
      'calificacionPromedio':
          (datosUsuario['calificacionPromedio'] as num?)?.toDouble() ?? 0,
      'cantidadTransacciones':
          (datosUsuario['cantidadTransacciones'] as num?)?.toInt() ?? 0,
    });
  }

  @override
  Future<void> actualizarTelefono({
    required String uid,
    required String telefono,
  }) async {
    await _usersRef.doc(uid).update({'telefono': telefono});
  }

  @override
  Future<void> actualizarNombre({
    required String uid,
    required String nombre,
  }) async {
    await _usersRef.doc(uid).update({'nombre': nombre});
    await _perfilesPublicosRef.doc(uid).update({'nombre': nombre});
  }

  @override
  Future<void> actualizarFoto({
    required String uid,
    required String fotoUrl,
  }) async {
    await _usersRef.doc(uid).update({'fotoUrl': fotoUrl});
    await _perfilesPublicosRef.doc(uid).update({'fotoUrl': fotoUrl});
  }
}
