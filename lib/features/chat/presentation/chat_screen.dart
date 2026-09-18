import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../acuerdos/data/acuerdo_repository.dart';
import '../../acuerdos/providers/acuerdo_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalogo/models/publicacion.dart';
import '../../catalogo/providers/catalogo_providers.dart';
import '../data/chat_repository.dart';
import '../models/conversacion.dart';
import '../models/mensaje.dart';
import '../providers/chat_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversacion});

  final Conversacion conversacion;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _mensajeController = TextEditingController();

  Publicacion? _publicacion;
  bool _cerrandoAcuerdo = false;

  @override
  void initState() {
    super.initState();
    _cargarPublicacion();
  }

  Future<void> _cargarPublicacion() async {
    try {
      final publicacion = await ref
          .read(publicacionRepositoryProvider)
          .obtenerPorId(widget.conversacion.publicacionId);
      if (mounted) setState(() => _publicacion = publicacion);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ChatScreen._cargarPublicacion error: $error\n$stackTrace');
      }
    }
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty) return;
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    _mensajeController.clear();
    await ref
        .read(chatRepositoryProvider)
        .enviarMensaje(
          conversacionId: widget.conversacion.id,
          emisorId: usuario.uid,
          texto: texto,
        );
  }

  Future<void> _abrirDialogoCerrarAcuerdo() async {
    final publicacion = _publicacion;
    if (publicacion == null) return;

    final precioController = TextEditingController(
      text: publicacion.precio.toStringAsFixed(0),
    );
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar acuerdo'),
        content: TextField(
          controller: precioController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Precio acordado'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final precio = double.tryParse(
      precioController.text.replaceAll(',', '.'),
    );
    if (precio == null || precio <= 0) return;

    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    setState(() => _cerrandoAcuerdo = true);
    try {
      await ref
          .read(acuerdoRepositoryProvider)
          .cerrarAcuerdo(
            conversacionId: widget.conversacion.id,
            publicacionId: publicacion.id,
            compradorId: widget.conversacion.compradorId,
            vendedorId: usuario.uid,
            precioAcordado: precio,
          );
      await _cargarPublicacion();
    } on PublicacionNoDisponibleException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta publicación ya no está disponible.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cerrar el acuerdo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cerrandoAcuerdo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final miUid = ref.read(authRepositoryProvider).currentUser?.uid;
    final ChatRepository chatRepository = ref.read(chatRepositoryProvider);

    final publicacion = _publicacion;
    final puedoOfrecerCierre =
        publicacion != null &&
        publicacion.vendedorId == miUid &&
        publicacion.estado == EstadoPublicacion.disponible;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversacion.publicacionTitulo),
        actions: [
          if (puedoOfrecerCierre)
            TextButton(
              onPressed: _cerrandoAcuerdo ? null : _abrirDialogoCerrarAcuerdo,
              child: const Text('Cerrar acuerdo'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Mensaje>>(
              stream: chatRepository.mensajes(widget.conversacion.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar los mensajes.'),
                  );
                }
                final mensajes = snapshot.data ?? [];
                if (mensajes.isEmpty) {
                  return const Center(
                    child: Text('Escribí el primer mensaje.'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final mensaje = mensajes[mensajes.length - 1 - index];
                    if (mensaje.tipo == TipoMensaje.sistema) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            mensaje.texto,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      );
                    }
                    final esMio = mensaje.emisorId == miUid;
                    return Align(
                      alignment: esMio
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: esMio
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(mensaje.texto),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      decoration: const InputDecoration(
                        hintText: 'Escribí un mensaje...',
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _enviar),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
