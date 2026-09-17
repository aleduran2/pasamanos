import 'package:flutter/material.dart';

import '../models/publicacion.dart';

class PublicacionListTile extends StatelessWidget {
  const PublicacionListTile({
    super.key,
    required this.publicacion,
    required this.onTap,
  });

  final Publicacion publicacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          publicacion.fotos.frente,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.image_not_supported_outlined),
          ),
        ),
      ),
      title: Text(publicacion.titulo),
      subtitle: Text('\$${publicacion.precio.toStringAsFixed(0)}'),
      onTap: onTap,
    );
  }
}
