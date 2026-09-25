import 'package:flutter/material.dart';

/// Par de botones para el `actions` de un [AlertDialog], uno al lado del
/// otro ocupando cada uno la mitad del ancho — en vez de dejar que
/// Flutter los apile en columna cuando no entran en una sola fila (el
/// comportamiento por defecto de Material 3).
class DialogoBotones extends StatelessWidget {
  const DialogoBotones({
    super.key,
    required this.textoCancelar,
    required this.textoConfirmar,
    required this.onCancelar,
    required this.onConfirmar,
    this.contenidoConfirmar,
  });

  final String textoCancelar;
  final String textoConfirmar;
  final VoidCallback? onCancelar;
  final VoidCallback? onConfirmar;

  /// Reemplaza el texto del botón de confirmar cuando hace falta mostrar
  /// otra cosa mientras se procesa (p. ej. un spinner).
  final Widget? contenidoConfirmar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancelar,
            child: Text(textoCancelar),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: onConfirmar,
            child: contenidoConfirmar ?? Text(textoConfirmar),
          ),
        ),
      ],
    );
  }
}
