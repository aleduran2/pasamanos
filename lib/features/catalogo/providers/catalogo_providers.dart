import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_upload_service.dart';
import '../data/publicacion_repository.dart';

final publicacionRepositoryProvider = Provider<PublicacionRepository>((ref) {
  return FirestorePublicacionRepository();
});

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return FirebaseImageUploadService();
});
