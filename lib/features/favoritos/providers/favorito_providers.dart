import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/favorito_repository.dart';

final favoritoRepositoryProvider = Provider<FavoritoRepository>((ref) {
  return FirestoreFavoritoRepository();
});
