import 'package:flutter/material.dart';

/// Estado vacío reutilizable: ícono en un círculo suave + mensaje, en vez de
/// solo texto plano. Se usa en listados (mis publicaciones, búsqueda,
/// conversaciones) cuando todavía no hay nada que mostrar.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.mensaje});

  final IconData icon;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
