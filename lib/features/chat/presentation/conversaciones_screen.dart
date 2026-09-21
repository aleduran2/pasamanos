import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/conversacion.dart';
import '../providers/chat_providers.dart';
import 'chat_screen.dart';

class ConversacionesScreen extends ConsumerWidget {
  const ConversacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    final colorScheme = Theme.of(context).colorScheme;

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
                  return const EmptyState(
                    icon: Icons.error_outline_rounded,
                    mensaje: 'No se pudieron cargar tus conversaciones.',
                  );
                }
                final conversaciones = snapshot.data ?? [];
                if (conversaciones.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    mensaje:
                        'Todavía no tenés conversaciones.\nEscribile a un vendedor desde un producto.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemCount: conversaciones.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final conversacion = conversaciones[index];
                    final noLeido = conversacion.noLeidoPor(usuario.uid);
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.storefront_rounded,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        conversacion.publicacionTitulo,
                        style: TextStyle(
                          fontWeight: noLeido
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        conversacion.ultimoMensaje ?? 'Sin mensajes todavía',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: noLeido
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: noLeido
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: noLeido
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
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
