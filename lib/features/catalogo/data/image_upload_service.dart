import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

abstract class ImageUploadService {
  Future<String> subir({
    required File archivo,
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
    required String publicacionId,
    required String nombreArchivo,
  }) async {
    final ref = _storage.ref('publicaciones/$publicacionId/$nombreArchivo.jpg');
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }
}
