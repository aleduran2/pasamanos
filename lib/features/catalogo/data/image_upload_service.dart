import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

abstract class ImageUploadService {
  /// La ruta incluye [vendedorId] (no solo [publicacionId]) para que las
  /// reglas de seguridad de Storage puedan validar quién puede escribir
  /// sin depender de que el documento de Firestore ya exista — las fotos
  /// se suben antes de crear la publicación.
  Future<String> subir({
    required File archivo,
    required String vendedorId,
    required String publicacionId,
    required String nombreArchivo,
  });

  /// Borra todas las fotos de una publicación (se llama al eliminarla).
  /// Falla en silencio: si algo sale mal acá no debería impedir que la
  /// publicación en sí se termine de borrar de Firestore.
  Future<void> eliminarFotos({
    required String vendedorId,
    required String publicacionId,
  });

  /// Sube la foto de perfil de una usuaria. Siempre el mismo nombre de
  /// archivo (una sola foto por cuenta), así que subir una nueva
  /// reemplaza la anterior sin dejar huérfanos en Storage.
  Future<String> subirAvatar({required File archivo, required String uid});
}

class FirebaseImageUploadService implements ImageUploadService {
  FirebaseImageUploadService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> subir({
    required File archivo,
    required String vendedorId,
    required String publicacionId,
    required String nombreArchivo,
  }) async {
    final ref = _storage.ref(
      'publicaciones/$vendedorId/$publicacionId/$nombreArchivo.jpg',
    );
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }

  @override
  Future<void> eliminarFotos({
    required String vendedorId,
    required String publicacionId,
  }) async {
    try {
      final carpeta = _storage.ref('publicaciones/$vendedorId/$publicacionId');
      final listado = await carpeta.listAll();
      await Future.wait(listado.items.map((item) => item.delete()));
    } catch (_) {
      // No debe impedir que se borre la publicación en Firestore.
    }
  }

  @override
  Future<String> subirAvatar({
    required File archivo,
    required String uid,
  }) async {
    final ref = _storage.ref('avatares/$uid/foto.jpg');
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }
}
