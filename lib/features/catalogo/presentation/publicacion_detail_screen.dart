import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formato.dart';
import '../../../core/widgets/favorito_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/providers/chat_providers.dart';
import '../../favoritos/providers/favorito_providers.dart';
import '../../perfil/models/perfil_publico.dart';
import '../../perfil/providers/perfil_providers.dart';
import '../models/publicacion.dart';
import '../providers/catalogo_providers.dart';
import 'publicar_producto_screen.dart';

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
  int _fotoActual = 0;
  bool _esFavorito = false;
  bool _eliminando = false;
  PerfilPublico? _perfilVendedora;
  late Publicacion _publicacion = widget.publicacion;

  @override
  void initState() {
    super.initState();
    _registrarVista();
    _cargarFavorito();
    _cargarPerfilVendedora();
  }

  Future<void> _cargarPerfilVendedora() async {
    try {
      final perfil = await ref
          .read(perfilPublicoRepositoryProvider)
          .obtenerPorId(widget.publicacion.vendedorId);
      if (mounted) setState(() => _perfilVendedora = perfil);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'PublicacionDetailScreen._cargarPerfilVendedora error: $error\n$stackTrace',
        );
      }
    }
  }

  void _registrarVista() {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario != null && usuario.uid == widget.publicacion.vendedorId) {
      return;
    }
    ref.read(publicacionRepositoryProvider).registrarVista(widget.publicacion.id);
  }

  Future<void> _cargarFavorito() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    final esFavorito = await ref
        .read(favoritoRepositoryProvider)
        .esFavorito(uid: usuario.uid, publicacionId: widget.publicacion.id);
    if (mounted) setState(() => _esFavorito = esFavorito);
  }

  Future<void> _alternarFavorito() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    setState(() => _esFavorito = !_esFavorito);
    await ref.read(favoritoRepositoryProvider).marcar(
      uid: usuario.uid,
      publicacionId: widget.publicacion.id,
      favorito: _esFavorito,
    );
  }

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
          content: Text(
            'No se pudo iniciar la conversación. Intentá de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _contactando = false);
    }
  }

  Future<void> _editar() async {
    final editada = await Navigator.of(context).push<Publicacion>(
      MaterialPageRoute(
        builder: (_) =>
            PublicarProductoScreen(publicacionExistente: _publicacion),
      ),
    );
    if (editada != null && mounted) setState(() => _publicacion = editada);
  }

  Future<void> _eliminar() async {
    final esReservada = _publicacion.estado == EstadoPublicacion.reservado;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: Text(
          esReservada
              ? 'Esta publicación tiene una reserva activa. Si la '
                    'eliminás, esa conversación queda sin la publicación '
                    'asociada. Esta acción no se puede deshacer.'
              : 'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _eliminando = true);
    try {
      await ref.read(publicacionRepositoryProvider).eliminar(_publicacion.id);
      // Se borra en paralelo/después, sin bloquear: si falla, la
      // publicación igual ya no existe en Firestore (lo que importa para
      // el resto de la app), y quedaría a lo sumo un archivo huérfano en
      // Storage.
      unawaited(
        ref.read(imageUploadServiceProvider).eliminarFotos(
          vendedorId: _publicacion.vendedorId,
          publicacionId: _publicacion.id,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar la publicación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  String get _etiquetaEstado => switch (_publicacion.estado) {
    EstadoPublicacion.reservado => 'Reservado',
    EstadoPublicacion.vendido => 'Vendido',
    EstadoPublicacion.disponible => '',
  };

  @override
  Widget build(BuildContext context) {
    final publicacion = _publicacion;
    final usuario = ref.watch(authRepositoryProvider).currentUser;
    final esMiPublicacion = usuario?.uid == publicacion.vendedorId;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final fotos = [
      publicacion.fotos.frente,
      publicacion.fotos.dorso,
      publicacion.fotos.etiqueta,
      publicacion.fotos.detalle,
    ].whereType<String>().toList();

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 300,
                      child: PageView(
                        onPageChanged: (indice) =>
                            setState(() => _fotoActual = indice),
                        children: fotos
                            .map(
                              (url) => Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: colorScheme.surfaceContainerHigh,
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: _BotonCirculoVolver(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    if (fotos.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            fotos.length,
                            (indice) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              width: indice == _fotoActual ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: indice == _fotoActual
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!esMiPublicacion)
                            FavoritoButton(
                              esFavorito: _esFavorito,
                              onTap: _alternarFavorito,
                              fondoOscuro: true,
                            ),
                          if (_etiquetaEstado.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(
                                _etiquetaEstado,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              backgroundColor: colorScheme.errorContainer,
                              side: BorderSide.none,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        publicacion.titulo,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_perfilVendedora != null &&
                          _perfilVendedora!.cantidadTransacciones > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _perfilVendedora!.calificacionPromedio
                                  .toStringAsFixed(1),
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${_perfilVendedora!.cantidadTransacciones} '
                              '${_perfilVendedora!.cantidadTransacciones == 1 ? 'venta' : 'ventas'})',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatearPrecio(publicacion.precio),
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (esMiPublicacion) ...[
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${publicacion.vistas} '
                                    '${publicacion.vistas == 1 ? 'vista' : 'vistas'}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _EtiquetaInformativa(
                            icono: publicacion.etapaEdad.icono,
                            texto: publicacion.etapaEdad.etiqueta,
                          ),
                          _EtiquetaInformativa(
                            texto: publicacion.categoria.etiqueta,
                          ),
                          if (publicacion.talle != null)
                            _EtiquetaInformativa(
                              icono: Icons.straighten_outlined,
                              texto: 'Talle ${publicacion.talle}',
                            ),
                          for (final color in publicacion.colores)
                            _EtiquetaInformativa(
                              icono: Icons.palette_outlined,
                              texto: color,
                            ),
                          if (publicacion.colegio != null)
                            _EtiquetaInformativa(
                              icono: Icons.school_outlined,
                              texto: publicacion.colegio!,
                            ),
                          if (publicacion.barrio != null)
                            _EtiquetaInformativa(
                              icono: Icons.place_outlined,
                              texto: publicacion.barrio!,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Descripción',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        publicacion.descripcion,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!esMiPublicacion)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: publicacion.estado == EstadoPublicacion.disponible
                    ? FilledButton.icon(
                        onPressed: _contactando ? null : _contactarVendedor,
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Contactar vendedor'),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          publicacion.estado == EstadoPublicacion.reservado
                              ? 'Esta publicación está reservada.'
                              : 'Esta publicación ya fue vendida.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          if (esMiPublicacion)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _eliminando ? null : _editar,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _eliminando ? null : _eliminar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                        ),
                        icon: _eliminando
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.error,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                        label: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Etiqueta de solo lectura (no es seleccionable). Con color de texto fijo
/// a mano: dejarlo sin especificar en un `Chip` puede terminar heredando un
/// color casi igual al fondo (mismo bug ya visto en los chips de filtros).
class _EtiquetaInformativa extends StatelessWidget {
  const _EtiquetaInformativa({required this.texto, this.icono});

  final String texto;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: icono != null
          ? Icon(icono, size: 18, color: colorScheme.onSurfaceVariant)
          : null,
      label: Text(texto),
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}

class _BotonCirculoVolver extends StatelessWidget {
  const _BotonCirculoVolver({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
