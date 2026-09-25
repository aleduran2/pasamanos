import 'package:flutter/material.dart';

import '../../../core/utils/formato.dart';
import '../../../core/widgets/favorito_button.dart';
import '../models/publicacion.dart';

class PublicacionListTile extends StatelessWidget {
  const PublicacionListTile({
    super.key,
    required this.publicacion,
    required this.onTap,
    this.mostrarVistas = false,
    this.mostrarFavorito = false,
    this.esFavorito = false,
    this.onToggleFavorito,
  });

  final Publicacion publicacion;
  final VoidCallback onTap;

  /// Muestra cuántas veces se vio la publicación (para la vendedora, en
  /// "Mis publicaciones").
  final bool mostrarVistas;

  /// Muestra el corazón de favoritos sobre la foto (para quien compra).
  final bool mostrarFavorito;
  final bool esFavorito;
  final VoidCallback? onToggleFavorito;

  int get _cantidadFotos => [
    publicacion.fotos.frente,
    publicacion.fotos.dorso,
    publicacion.fotos.etiqueta,
    publicacion.fotos.detalle,
  ].whereType<String>().length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      publicacion.fotos.frente,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 84,
                        height: 84,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  if (mostrarFavorito)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: FavoritoButton(
                        esFavorito: esFavorito,
                        onTap: onToggleFavorito ?? () {},
                        compacto: true,
                      ),
                    ),
                  if (publicacion.estaDestacada)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.amber[800],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_cantidadFotos > 1)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$_cantidadFotos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 84),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publicacion.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            publicacion.etapaEdad.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (mostrarVistas) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${publicacion.vistas} '
                                  '${publicacion.vistas == 1 ? 'vista' : 'vistas'}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatearPrecio(publicacion.precio),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (publicacion.estado != EstadoPublicacion.disponible)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                publicacion.estado ==
                                        EstadoPublicacion.reservado
                                    ? 'Reservado'
                                    : 'Vendido',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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
