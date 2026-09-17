import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/providers/chat_providers.dart';
import '../models/publicacion.dart';

class PublicacionDetailScreen extends ConsumerStatefulWidget {
  const PublicacionDetailScreen({super.key, required this.publicacion});

  final Publicacion publicacion;

  @override
  ConsumerState<PublicacionDetailScreen> createState() =>
      _PublicacionDetailScreenState();
}

class _PublicacionDetailScreenState
    extends ConsumerState<PublicacionDetailScreen> {
  bool _contactando = false;

  Future<void> _contactarVendedor() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    setState(() => _contactando = true);
    try {
      final conversacion = await ref
          .read(chatRepositoryProvider)
          .obtenerOCrear(
            publicacionId: widget.publicacion.id,
            publicacionTitulo: widget.publicacion.titulo,
            compradorId: usuario.uid,
            vendedorId: widget.publicacion.vendedorId,
          );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversacion: conversacion),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo iniciar la conversación. Intentá de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _contactando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicacion = widget.publicacion;
    final usuario = ref.watch(authRepositoryProvider).currentUser;
    final esMiPublicacion = usuario?.uid == publicacion.vendedorId;

    final fotos = [
      publicacion.fotos.frente,
      publicacion.fotos.dorso,
      publicacion.fotos.etiqueta,
      publicacion.fotos.detalle,
    ].whereType<String>().toList();

    return Scaffold(
      appBar: AppBar(title: Text(publicacion.titulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 220,
            child: PageView(
              children: fotos
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '\$${publicacion.precio.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(publicacion.descripcion),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(publicacion.categoria.etiqueta)),
              Chip(label: Text(publicacion.etapaEdad.etiqueta)),
              if (publicacion.colegio != null)
                Chip(label: Text(publicacion.colegio!)),
              if (publicacion.barrio != null)
                Chip(label: Text(publicacion.barrio!)),
            ],
          ),
          if (!esMiPublicacion) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _contactando ? null : _contactarVendedor,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Contactar vendedor'),
            ),
          ],
        ],
      ),
    );
  }
}
