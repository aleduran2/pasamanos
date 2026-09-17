import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalogo/models/publicacion.dart';
import '../../catalogo/presentation/publicacion_detail_screen.dart';
import '../../catalogo/presentation/publicacion_list_tile.dart';
import '../../catalogo/providers/catalogo_providers.dart';

class BusquedaScreen extends ConsumerStatefulWidget {
  const BusquedaScreen({super.key});

  @override
  ConsumerState<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends ConsumerState<BusquedaScreen> {
  final _colegioController = TextEditingController();
  final _barrioController = TextEditingController();

  EtapaEdad? _etapaSeleccionada;
  Categoria? _categoriaSeleccionada;
  Future<List<Publicacion>>? _futuro;

  @override
  void dispose() {
    _colegioController.dispose();
    _barrioController.dispose();
    super.dispose();
  }

  void _buscar() {
    final etapa = _etapaSeleccionada;
    if (etapa == null) {
      setState(() => _futuro = null);
      return;
    }
    setState(() {
      _futuro = ref.read(publicacionRepositoryProvider).buscarDisponibles(
        etapaEdad: etapa,
        categoria: _categoriaSeleccionada,
        colegio: _colegioController.text,
        barrio: _barrioController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar productos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etapa / edad',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: EtapaEdad.values
                      .map(
                        (etapa) => ChoiceChip(
                          label: Text(etapa.etiqueta),
                          selected: _etapaSeleccionada == etapa,
                          onSelected: (seleccionado) {
                            setState(
                              () => _etapaSeleccionada =
                                  seleccionado ? etapa : null,
                            );
                            _buscar();
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          ExpansionTile(
            title: const Text('Más filtros (opcional)'),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            children: [
              DropdownButtonFormField<Categoria?>(
                initialValue: _categoriaSeleccionada,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...Categoria.values.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c.etiqueta)),
                  ),
                ],
                onChanged: (valor) {
                  setState(() => _categoriaSeleccionada = valor);
                  _buscar();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _colegioController,
                decoration: const InputDecoration(
                  labelText: 'Colegio (opcional)',
                ),
                onSubmitted: (_) => _buscar(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _barrioController,
                decoration: const InputDecoration(
                  labelText: 'Barrio (opcional)',
                ),
                onSubmitted: (_) => _buscar(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _etapaSeleccionada == null ? null : _buscar,
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(child: _construirResultados()),
        ],
      ),
    );
  }

  Widget _construirResultados() {
    if (_etapaSeleccionada == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Elegí una etapa/edad para ver los productos disponibles.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return FutureBuilder<List<Publicacion>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudo buscar. Intentá de nuevo.'));
        }
        final publicaciones = snapshot.data ?? [];
        if (publicaciones.isEmpty) {
          return const Center(
            child: Text('No encontramos productos con esos filtros.'),
          );
        }
        return ListView.builder(
          itemCount: publicaciones.length,
          itemBuilder: (context, index) {
            final publicacion = publicaciones[index];
            return PublicacionListTile(
              publicacion: publicacion,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PublicacionDetailScreen(publicacion: publicacion),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
