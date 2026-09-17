import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final miUid = ref.read(authRepositoryProvider).currentUser?.uid;
    final ChatRepository chatRepository = ref.read(chatRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.conversacion.publicacionTitulo)),
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
