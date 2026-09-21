import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mercadopago_repository.dart';
import '../data/perfil_publico_repository.dart';
import '../data/user_profile_repository.dart';

final mercadoPagoRepositoryProvider = Provider<MercadoPagoRepository>((ref) {
  return FirestoreMercadoPagoRepository();
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return FirestoreUserProfileRepository();
});

final perfilPublicoRepositoryProvider = Provider<PerfilPublicoRepository>((
  ref,
) {
  return FirestorePerfilPublicoRepository();
});
