import 'dart:io';

import 'package:flutter/material.dart';

class PhotoSlot extends StatelessWidget {
  const PhotoSlot({
    super.key,
    required this.etiqueta,
    required this.archivo,
    required this.onTap,
    this.urlExistente,
    this.onQuitar,
    this.requerido = false,
  });

  final String etiqueta;
  final File? archivo;

  /// Foto ya subida (editando una publicación existente). Si [archivo] no
  /// es null, tiene prioridad — significa que se eligió una nueva.
  final String? urlExistente;
  final VoidCallback onTap;

  /// Si no es null, aparece un botón para vaciar el casillero (solo tiene
  /// sentido en fotos opcionales — la de frente no se puede quitar).
  final VoidCallback? onQuitar;
  final bool requerido;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tieneFoto = archivo != null || urlExistente != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: 128,
        decoration: BoxDecoration(
          color: tieneFoto
              ? null
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(
            color: tieneFoto
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: tieneFoto ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _construirPreview(colorScheme),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: tieneFoto
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : (requerido
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink()),
            ),
            if (tieneFoto && onQuitar != null)
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: onQuitar,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirPreview(ColorScheme colorScheme) {
    if (archivo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(archivo!, fit: BoxFit.cover, width: double.infinity),
      );
    }
    if (urlExistente != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          urlExistente!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.image_not_supported_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.add_a_photo_rounded,
        color: colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}
