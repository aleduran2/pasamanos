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
}
