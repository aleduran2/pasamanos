import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/alerta_repository.dart';

final alertaRepositoryProvider = Provider<AlertaRepository>((ref) {
  return FirestoreAlertaRepository();
});
