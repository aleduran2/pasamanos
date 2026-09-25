import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/talles.dart';
import '../../../core/widgets/dialogo_botones.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalogo/models/publicacion.dart';
import '../models/alerta.dart';
import '../providers/alerta_providers.dart';

class AlertasScreen extends ConsumerStatefulWidget {
  const AlertasScreen({super.key});

  @override
  ConsumerState<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends ConsumerState<AlertasScreen> {
  Future<void> _nuevaAlerta() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    Categoria? categoria;
    String? talle;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva alerta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Categoría'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Categoria.values.map((valor) {
                  final seleccionada = categoria == valor;
                  final colorScheme = Theme.of(context).colorScheme;
                  return ChoiceChip(
                    label: Text(valor.etiqueta),
                    labelStyle: TextStyle(
                      color: seleccionada
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    selected: seleccionada,
                    selectedColor: colorScheme.primary,
                    onSelected: (_) => setDialogState(() {
                      categoria = valor;
                      talle = null;
                    }),
                  );
                }).toList(),
              ),
              if (tallesParaCategoria(categoria) case final talles?) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: talle,
                  decoration: const InputDecoration(labelText: 'Talle'),
                  isExpanded: true,
                  items: talles
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (valor) => setDialogState(() => talle = valor),
                ),
              ] else if (categoria != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Esta categoría no usa talles — elegí otra.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          actions: [
            DialogoBotones(
              textoCancelar: 'Cancelar',
              textoConfirmar: 'Crear alerta',
              onCancelar: () => Navigator.of(context).pop(false),
              onConfirmar: categoria == null || talle == null
                  ? null
                  : () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmado != true || categoria == null || talle == null) return;

    await ref
        .read(alertaRepositoryProvider)
        .crear(uid: usuario.uid, categoria: categoria!, talle: talle!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta creada.')),
      );
    }
  }

  Future<void> _eliminar(Alerta alerta) async {
    await ref.read(alertaRepositoryProvider).eliminar(alerta.id);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authRepositoryProvider).currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis alertas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaAlerta,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Nueva alerta'),
      ),
      body: usuario == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Alerta>>(
              stream: ref.read(alertaRepositoryProvider).misAlertas(usuario.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline_rounded,
                    mensaje: 'No se pudieron cargar tus alertas.',
                  );
                }
                final alertas = snapshot.data ?? [];
                if (alertas.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    mensaje:
                        'Todavía no tenés alertas. Creá una para que te '
                        'avisemos apenas aparezca tu talle.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: alertas.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final alerta = alertas[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Talle ${alerta.talle}',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  alerta.categoria.etiqueta,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Eliminar alerta',
                            onPressed: () => _eliminar(alerta),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
