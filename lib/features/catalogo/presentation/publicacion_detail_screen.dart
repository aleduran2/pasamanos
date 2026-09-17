import 'package:flutter/material.dart';

import '../models/publicacion.dart';

class PublicacionDetailScreen extends StatelessWidget {
  const PublicacionDetailScreen({super.key, required this.publicacion});

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context) {
    final fotos = [
      publicacion.fotos.frente,
      publicacion.fotos.dorso,
      publicacion.fotos.etiqueta,
      publicacion.fotos.detalle,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(publicacion.titulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 220,
            child: PageView(
              children: fotos
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '\$${publicacion.precio.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(publicacion.descripcion),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(publicacion.categoria.etiqueta)),
              Chip(label: Text(publicacion.etapaEdad.etiqueta)),
              if (publicacion.colegio != null)
                Chip(label: Text(publicacion.colegio!)),
              if (publicacion.barrio != null)
                Chip(label: Text(publicacion.barrio!)),
            ],
          ),
        ],
      ),
    );
  }
}
