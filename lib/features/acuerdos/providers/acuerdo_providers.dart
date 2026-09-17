import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/acuerdo_repository.dart';

final acuerdoRepositoryProvider = Provider<AcuerdoRepository>((ref) {
  return FirestoreAcuerdoRepository();
});
