import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/barrios_la_plata.dart';
import '../../../core/data/colegios_la_plata.dart';
import '../../../core/data/talles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/grilla_dos_columnas.dart';
import '../../../core/widgets/selector_con_otro.dart';
import '../../../core/widgets/selector_multiple_desplegable.dart';
import '../../../core/widgets/tarjeta_seleccionable.dart';
import '../../alertas/providers/alerta_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalogo/models/publicacion.dart';
import '../../catalogo/presentation/publicacion_detail_screen.dart';
import '../../catalogo/presentation/publicacion_list_tile.dart';
import '../../catalogo/providers/catalogo_providers.dart';
import '../../favoritos/providers/favorito_providers.dart';

enum _Orden { recientes, menorPrecio, mayorPrecio }

extension on _Orden {
  String get etiqueta => switch (this) {
    _Orden.recientes => 'Más recientes',
    _Orden.menorPrecio => 'Menor precio',
    _Orden.mayorPrecio => 'Mayor precio',
  };
}

class BusquedaScreen extends ConsumerStatefulWidget {
  const BusquedaScreen({super.key});

  @override
  ConsumerState<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends ConsumerState<BusquedaScreen> {
  EtapaEdad? _etapaSeleccionada;
  Categoria? _categoriaSeleccionada;
  String? _colegio;
  String? _barrio;
  String? _talle;
  final Set<String> _coloresSeleccionados = {};
  final _precioMinController = TextEditingController();
  final _precioMaxController = TextEditingController();
  _Orden _orden = _Orden.recientes;
  Future<List<Publicacion>>? _futuro;
  Set<String> _favoritoIds = {};
  bool _masFiltrosAbierto = false;

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  @override
  void dispose() {
    _precioMinController.dispose();
    _precioMaxController.dispose();
    super.dispose();
  }

  Future<void> _cargarFavoritos() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    final ids = await ref
        .read(favoritoRepositoryProvider)
        .idsFavoritos(usuario.uid)
        .first;
    if (mounted) setState(() => _favoritoIds = ids.toSet());
  }

  Future<void> _alternarFavorito(String publicacionId) async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    final marcarComoFavorito = !_favoritoIds.contains(publicacionId);
    setState(() {
      if (marcarComoFavorito) {
        _favoritoIds.add(publicacionId);
      } else {
        _favoritoIds.remove(publicacionId);
      }
    });
    await ref
        .read(favoritoRepositoryProvider)
        .marcar(
          uid: usuario.uid,
          publicacionId: publicacionId,
          favorito: marcarComoFavorito,
        );
  }

  void _buscar() {
    setState(() {
      _futuro = ref
          .read(publicacionRepositoryProvider)
          .buscarDisponibles(
            etapaEdad: _etapaSeleccionada,
            categoria: _categoriaSeleccionada,
            colegio: _colegio,
            barrio: _barrio,
            talle: tallesParaCategoria(_categoriaSeleccionada) != null
                ? _talle
                : null,
            colores: colorAplicaA(_categoriaSeleccionada)
                ? _coloresSeleccionados.toList()
                : null,
          );
    });
  }

  bool get _hayFiltrosSecundarios =>
      _categoriaSeleccionada != null ||
      _talle != null ||
      _coloresSeleccionados.isNotEmpty ||
      _colegio != null ||
      _barrio != null ||
      _precioMinController.text.isNotEmpty ||
      _precioMaxController.text.isNotEmpty;

  Future<void> _crearAlerta() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    final categoria = _categoriaSeleccionada;
    final talle = _talle;
    if (usuario == null || categoria == null || talle == null) return;

    await ref
        .read(alertaRepositoryProvider)
        .crear(uid: usuario.uid, categoria: categoria, talle: talle);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te vamos a avisar cuando aparezca este talle.'),
        ),
      );
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _categoriaSeleccionada = null;
      _talle = null;
      _coloresSeleccionados.clear();
      _colegio = null;
      _barrio = null;
      _precioMinController.clear();
      _precioMaxController.clear();
    });
    _buscar();
  }

  @override
  Widget build(BuildContext context) {
    // CustomScrollView (en vez de Column + Expanded) para que todo comparta
    // un solo scroll: evita el desborde cuando el teclado aparece con los
    // filtros extra desplegados.
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar productos')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etapa / edad',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  GrillaDosColumnas(
                    children: EtapaEdad.values.map((etapa) {
                      final seleccionado = _etapaSeleccionada == etapa;
                      return TarjetaSeleccionable(
                        etiqueta: etapa.etiqueta,
                        icono: etapa.icono,
                        seleccionado: seleccionado,
                        onSelected: () {
                          setState(
                            () => _etapaSeleccionada = seleccionado
                                ? null
                                : etapa,
                          );
                          _buscar();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            // Antes esto era un `ExpansionTile`, pero ese widget mantiene
            // sus hijos "montados pero invisibles" (via `Offstage`)
            // mientras está cerrado — combinado con los `TextField` de
            // precio de más abajo, eso rompe con "BoxConstraints forces an
            // infinite width" en el dispositivo real (no se reproducía en
            // los tests, que no llegan a ese detalle del renderer). Un
            // desplegable manual que solo construye el contenido cuando
            // está realmente abierto evita el problema de raíz.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Text('Más filtros'),
                  trailing: Icon(
                    _masFiltrosAbierto
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  onTap: () =>
                      setState(() => _masFiltrosAbierto = !_masFiltrosAbierto),
                ),
                if (_masFiltrosAbierto)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<Categoria?>(
                          initialValue: _categoriaSeleccionada,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todas'),
                            ),
                            ...Categoria.values.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.etiqueta),
                              ),
                            ),
                          ],
                          onChanged: (categoria) {
                            setState(() {
                              _categoriaSeleccionada = categoria;
                              _talle = null;
                            });
                            _buscar();
                          },
                        ),
                        if (tallesParaCategoria(_categoriaSeleccionada)
                            case final talles?) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: talles.contains(_talle)
                                ? _talle
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Talle',
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ...talles.map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              ),
                            ],
                            onChanged: (valor) {
                              setState(() => _talle = valor);
                              _buscar();
                            },
                          ),
                          if (_talle != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _crearAlerta,
                                icon: const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                label: const Text('Avisarme de este talle'),
                              ),
                            ),
                          ],
                        ],
                        if (colorAplicaA(_categoriaSeleccionada)) ...[
                          const SizedBox(height: 16),
                          SelectorMultipleDesplegable(
                            label: 'Color',
                            opciones: colores,
                            seleccionados: _coloresSeleccionados,
                            onChanged: (nuevo) {
                              setState(() {
                                _coloresSeleccionados
                                  ..clear()
                                  ..addAll(nuevo);
                              });
                              _buscar();
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Precio',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _precioMinController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Mínimo',
                                  prefixText: '\$ ',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _precioMaxController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Máximo',
                                  prefixText: '\$ ',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SelectorConOtro(
                          valorInicial: _colegio,
                          onChanged: (valor) =>
                              setState(() => _colegio = valor),
                          label: 'Colegio',
                          labelOtro: 'Nombre del colegio',
                          opciones: colegiosLaPlata,
                          valorOtro: colegioOtroValor,
                        ),
                        const SizedBox(height: 12),
                        SelectorConOtro(
                          valorInicial: _barrio,
                          onChanged: (valor) => setState(() => _barrio = valor),
                          label: 'Barrio',
                          labelOtro: 'Nombre del barrio',
                          opciones: barriosLaPlata,
                          valorOtro: barrioOtroValor,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _hayFiltrosSecundarios
                                  ? _limpiarFiltros
                                  : null,
                              child: const Text('Limpiar filtros'),
                            ),
                            const Spacer(),
                            // El tema global de FilledButton pide
                            // `minimumSize: Size.fromHeight(54)` (ancho
                            // mínimo infinito, para ocupar todo el ancho
                            // cuando es el único botón de la fila) — acá
                            // comparte fila con otro botón, así que sin
                            // este `Expanded` pide un ancho infinito
                            // dentro de una restricción acotada y tira
                            // "BoxConstraints forces an infinite width".
                            Expanded(
                              child: FilledButton(
                                onPressed: _buscar,
                                child: const Text('Aplicar filtros'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          ..._construirResultadosSlivers(),
        ],
      ),
    );
  }

  List<Widget> _construirResultadosSlivers() {
    if (_futuro == null) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.travel_explore_rounded,
            mensaje:
                'Elegí una etapa/edad o tocá "Aplicar filtros" para ver '
                'los productos disponibles.',
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<List<Publicacion>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const EmptyState(
                icon: Icons.error_outline_rounded,
                mensaje: 'No se pudo buscar. Intentá de nuevo.',
              );
            }
            var publicaciones = [...(snapshot.data ?? [])];
            final precioMin = double.tryParse(
              _precioMinController.text.replaceAll(',', '.'),
            );
            final precioMax = double.tryParse(
              _precioMaxController.text.replaceAll(',', '.'),
            );
            if (precioMin != null) {
              publicaciones = publicaciones
                  .where((p) => p.precio >= precioMin)
                  .toList();
            }
            if (precioMax != null) {
              publicaciones = publicaciones
                  .where((p) => p.precio <= precioMax)
                  .toList();
            }
            if (publicaciones.isEmpty) {
              return const EmptyState(
                icon: Icons.search_off_rounded,
                mensaje: 'No encontramos productos con esos filtros.',
              );
            }
            switch (_orden) {
              case _Orden.recientes:
                break;
              case _Orden.menorPrecio:
                publicaciones.sort((a, b) => a.precio.compareTo(b.precio));
              case _Orden.mayorPrecio:
                publicaciones.sort((a, b) => b.precio.compareTo(a.precio));
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${publicaciones.length} '
                        '${publicaciones.length == 1 ? 'resultado' : 'resultados'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      _SelectorOrden(
                        valor: _orden,
                        onChanged: (valor) => setState(() => _orden = valor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final publicacion in publicaciones) ...[
                    PublicacionListTile(
                      publicacion: publicacion,
                      mostrarFavorito: true,
                      esFavorito: _favoritoIds.contains(publicacion.id),
                      onToggleFavorito: () => _alternarFavorito(publicacion.id),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicacionDetailScreen(publicacion: publicacion),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _SelectorOrden extends StatelessWidget {
  const _SelectorOrden({required this.valor, required this.onChanged});

  final _Orden valor;
  final ValueChanged<_Orden> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_Orden>(
      initialValue: valor,
      onSelected: onChanged,
      itemBuilder: (context) => _Orden.values
          .map((o) => PopupMenuItem(value: o, child: Text(o.etiqueta)))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              valor.etiqueta,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
