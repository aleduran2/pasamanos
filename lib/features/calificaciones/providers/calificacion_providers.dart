import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calificacion_repository.dart';

final calificacionRepositoryProvider = Provider<CalificacionRepository>((ref) {
  return FirestoreCalificacionRepository();
});
