import 'package:flutter/material.dart';

/// Tarjeta de selección (en vez de un chip): con etiquetas largas, un chip
/// de ancho fijo terminaría cortando el texto a la mitad. Acá el texto
/// puede ocupar hasta dos líneas y queda centrado, así que se lee entero
/// sin importar el largo. Pensada para usarse dentro de [GrillaDosColumnas].
class TarjetaSeleccionable extends StatelessWidget {
  const TarjetaSeleccionable({
    super.key,
    required this.etiqueta,
    required this.seleccionado,
    required this.onSelected,
    this.icono,
  });

  final String etiqueta;
  final IconData? icono;
  final bool seleccionado;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorTexto = seleccionado
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    return Material(
      color: seleccionado ? colorScheme.primary : colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: seleccionado ? Colors.transparent : colorScheme.outline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 18, color: colorTexto),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorTexto,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
