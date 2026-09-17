import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../busqueda/presentation/busqueda_screen.dart';
import '../../catalogo/models/publicacion.dart';
import '../../catalogo/presentation/publicacion_detail_screen.dart';
import '../../catalogo/presentation/publicacion_list_tile.dart';
import '../../catalogo/presentation/publicar_producto_screen.dart';
import '../../catalogo/providers/catalogo_providers.dart';
import '../../chat/presentation/conversaciones_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<List<Publicacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargarMisPublicaciones();
  }

  Future<List<Publicacion>> _cargarMisPublicaciones() {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return Future.value(const []);
    return ref.read(publicacionRepositoryProvider).listarPorVendedor(usuario.uid);
  }

  Future<void> _irAPublicar() async {
    final publicado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PublicarProductoScreen()),
    );
    if (publicado == true) {
      setState(() => _futuro = _cargarMisPublicaciones());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasamanos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar productos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BusquedaScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Mensajes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConversacionesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAPublicar,
        icon: const Icon(Icons.add),
        label: const Text('Publicar producto'),
      ),
      body: FutureBuilder<List<Publicacion>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('No se pudieron cargar tus publicaciones.'),
            );
          }
          final publicaciones = snapshot.data ?? [];
          if (publicaciones.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no publicaste nada.\nTocá "Publicar producto" para empezar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: publicaciones.length,
            itemBuilder: (context, index) {
              final publicacion = publicaciones[index];
              return PublicacionListTile(
                publicacion: publicacion,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PublicacionDetailScreen(publicacion: publicacion),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
