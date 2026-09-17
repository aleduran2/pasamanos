import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/conversacion.dart';
import '../providers/chat_providers.dart';
import 'chat_screen.dart';

class ConversacionesScreen extends ConsumerWidget {
  const ConversacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.read(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: usuario == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Conversacion>>(
              stream: ref
                  .read(chatRepositoryProvider)
                  .misConversaciones(usuario.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar tus conversaciones.'),
                  );
                }
                final conversaciones = snapshot.data ?? [];
                if (conversaciones.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no tenés conversaciones.\nEscribile a un vendedor desde un producto.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: conversaciones.length,
                  itemBuilder: (context, index) {
                    final conversacion = conversaciones[index];
                    return ListTile(
                      title: Text(conversacion.publicacionTitulo),
                      subtitle: Text(
                        conversacion.ultimoMensaje ?? 'Sin mensajes todavía',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(conversacion: conversacion),
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
