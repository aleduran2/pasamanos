import 'package:flutter/material.dart';

/// Botón de corazón para marcar/desmarcar favoritos. Es "controlado": el
/// padre guarda el estado real (para poder refrescar listas, contadores,
/// etc.) y este widget solo dibuja el ícono y avisa el toque.
class FavoritoButton extends StatelessWidget {
  const FavoritoButton({
    super.key,
    required this.esFavorito,
    required this.onTap,
    this.fondoOscuro = false,
    this.compacto = false,
  });

  final bool esFavorito;
  final VoidCallback onTap;

  /// true cuando el botón flota sobre una foto (fondo oscuro semitransparente
  /// en vez del fondo claro tipo "card").
  final bool fondoOscuro;

  /// true para la miniatura de la lista (32x32 en vez de 38x38) — el ícono
  /// y el relleno se ajustan para llenar justo ese tamaño. Si el botón
  /// queda apretado dentro de una caja más chica de lo que pide, Flutter lo
  /// encoge de forma asimétrica y el corazón se ve descentrado.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tamanoIcono = compacto ? 18.0 : 22.0;
    final relleno = compacto ? 7.0 : 8.0;
    return Material(
      color: fondoOscuro
          ? Colors.black.withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(relleno),
          child: Icon(
            esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: esFavorito
                ? const Color(0xFFE64556)
                : (fondoOscuro ? Colors.white : Colors.black54),
            size: tamanoIcono,
          ),
        ),
      ),
    );
  }
}
