import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalogo/models/publicacion.dart';
import '../../catalogo/presentation/publicacion_detail_screen.dart';
import '../../catalogo/presentation/publicacion_list_tile.dart';
import '../../catalogo/providers/catalogo_providers.dart';
import '../providers/favorito_providers.dart';

class FavoritosScreen extends ConsumerStatefulWidget {
  const FavoritosScreen({super.key});

  @override
  ConsumerState<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends ConsumerState<FavoritosScreen> {
  Future<void> _quitar(String uid, String publicacionId) {
    return ref.read(favoritoRepositoryProvider).marcar(
      uid: uid,
      publicacionId: publicacionId,
      favorito: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: usuario == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<String>>(
              stream: ref.read(favoritoRepositoryProvider).idsFavoritos(usuario.uid),
              builder: (context, snapshotIds) {
                if (snapshotIds.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshotIds.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline_rounded,
                    mensaje: 'No se pudieron cargar tus favoritos.',
                  );
                }
                final ids = snapshotIds.data ?? [];
                if (ids.isEmpty) {
                  return const EmptyState(
                    icon: Icons.favorite_border_rounded,
                    mensaje:
                        'Todavía no marcaste favoritos.\nTocá el corazón en un producto para guardarlo acá.',
                  );
                }
                return FutureBuilder<List<Publicacion>>(
                  future: Future.wait(
                    ids.map(
                      (id) => ref.read(publicacionRepositoryProvider).obtenerPorId(id),
                    ),
                  ).then((lista) => lista.whereType<Publicacion>().toList()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final publicaciones = snapshot.data ?? [];
                    if (publicaciones.isEmpty) {
                      return const EmptyState(
                        icon: Icons.favorite_border_rounded,
                        mensaje: 'Tus favoritos ya no están disponibles.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: publicaciones.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final publicacion = publicaciones[index];
                        return PublicacionListTile(
                          publicacion: publicacion,
                          mostrarFavorito: true,
                          esFavorito: true,
                          onToggleFavorito: () =>
                              _quitar(usuario.uid, publicacion.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PublicacionDetailScreen(
                                publicacion: publicacion,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
