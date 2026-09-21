import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/barrios_la_plata.dart';
import '../../../core/data/colegios_la_plata.dart';
import '../../../core/data/talles.dart';
import '../../../core/widgets/selector_con_otro.dart';
import '../../../core/widgets/selector_multiple_desplegable.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/publicacion.dart';
import '../providers/catalogo_providers.dart';
import 'photo_slot.dart';

// Etiquetas cortas a propósito: si alguna envolviera a dos líneas y las
// demás no, el ícono de cada casillero quedaría a distinta altura (ya
// pasó con "Dorso (opcional)" vs "Frente"). La aclaración de qué es
// obligatorio ya está en el subtítulo de la sección, no hace falta
// repetirla acá.
const _etiquetasFotos = {
  'frente': 'Frente',
  'dorso': 'Dorso',
  'etiqueta': 'Etiqueta',
  'detalle': 'Detalle',
};

class PublicarProductoScreen extends ConsumerStatefulWidget {
  const PublicarProductoScreen({super.key, this.publicacionExistente});

  /// Si viene una publicación, la pantalla edita esa en vez de crear una
  /// nueva: precarga todos los campos y las fotos ya subidas.
  final Publicacion? publicacionExistente;

  @override
  ConsumerState<PublicarProductoScreen> createState() =>
      _PublicarProductoScreenState();
}

class _PublicarProductoScreenState
    extends ConsumerState<PublicarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloController = TextEditingController(
    text: widget.publicacionExistente?.titulo,
  );
  late final _descripcionController = TextEditingController(
    text: widget.publicacionExistente?.descripcion,
  );
  late final _precioController = TextEditingController(
    text: widget.publicacionExistente?.precio.toStringAsFixed(0),
  );
  late String? _colegio = widget.publicacionExistente?.colegio;
  late String? _barrio = widget.publicacionExistente?.barrio;
  late String? _talle = widget.publicacionExistente?.talle;
  late final Set<String> _colores = {
    ...?widget.publicacionExistente?.colores,
  };

  final Map<String, File?> _fotosNuevas = {
    'frente': null,
    'dorso': null,
    'etiqueta': null,
    'detalle': null,
  };
  late final Map<String, String?> _fotosExistentes = {
    'frente': widget.publicacionExistente?.fotos.frente,
    'dorso': widget.publicacionExistente?.fotos.dorso,
    'etiqueta': widget.publicacionExistente?.fotos.etiqueta,
    'detalle': widget.publicacionExistente?.fotos.detalle,
  };

  late Categoria _categoria =
      widget.publicacionExistente?.categoria ?? Categoria.ropa;
  late EtapaEdad _etapaEdad =
      widget.publicacionExistente?.etapaEdad ?? EtapaEdad.primaria;
  bool _publicando = false;

  bool get _editando => widget.publicacionExistente != null;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  bool get _faltaFoto =>
      _fotosNuevas['frente'] == null && _fotosExistentes['frente'] == null;

  void _quitarFoto(String slot) {
    setState(() {
      _fotosNuevas[slot] = null;
      _fotosExistentes[slot] = null;
    });
  }

  Future<void> _elegirFoto(String slot) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Sacar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;

    final archivo = await ImagePicker().pickImage(
      source: origen,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (archivo == null) return;

    setState(() => _fotosNuevas[slot] = File(archivo.path));
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_faltaFoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta la foto de frente.')),
      );
      return;
    }
    if (tallesParaCategoria(_categoria) != null && _talle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un talle.')),
      );
      return;
    }
    if (colorAplicaA(_categoria) && _colores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí al menos un color.')),
      );
      return;
    }

    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    setState(() => _publicando = true);
    try {
      final repositorio = ref.read(publicacionRepositoryProvider);
      final subidor = ref.read(imageUploadServiceProvider);
      final existente = widget.publicacionExistente;
      final id = existente?.id ?? repositorio.generarId();
      final vendedorId = existente?.vendedorId ?? usuario.uid;

      final urls = <String, String?>{};
      for (final slot in _etiquetasFotos.keys) {
        final archivoNuevo = _fotosNuevas[slot];
        if (archivoNuevo != null) {
          urls[slot] = await subidor.subir(
            archivo: archivoNuevo,
            vendedorId: vendedorId,
            publicacionId: id,
            nombreArchivo: slot,
          );
        } else {
          urls[slot] = _fotosExistentes[slot];
        }
      }

      final publicacion = Publicacion(
        id: id,
        vendedorId: vendedorId,
        titulo: _tituloController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        categoria: _categoria,
        etapaEdad: _etapaEdad,
        precio: double.parse(_precioController.text.replaceAll(',', '.')),
        fotos: FotosPublicacion(
          frente: urls['frente']!,
          dorso: urls['dorso'],
          etiqueta: urls['etiqueta'],
          detalle: urls['detalle'],
        ),
        colegio: _colegio,
        barrio: _barrio,
        talle: tallesParaCategoria(_categoria) != null ? _talle : null,
        colores: colorAplicaA(_categoria) ? _colores.toList() : const [],
        estado: existente?.estado ?? EstadoPublicacion.disponible,
        fechaPublicacion: existente?.fechaPublicacion,
        vistas: existente?.vistas ?? 0,
      );

      if (_editando) {
        await repositorio.actualizar(publicacion);
      } else {
        await repositorio.guardar(publicacion);
      }

      // Se devuelve la publicación ya armada (no solo `true`) para que la
      // pantalla anterior la pueda mostrar de inmediato sin depender de un
      // segundo viaje a Firestore — evita que la nueva publicación tarde
      // en aparecer si `fechaPublicacion` (server timestamp) todavía no se
      // terminó de resolver del lado del servidor.
      if (mounted) Navigator.of(context).pop(publicacion);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editando
                ? 'No se pudo guardar los cambios. Intentá de nuevo.'
                : 'No se pudo publicar. Intentá de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar producto' : 'Publicar producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SeccionFormulario(
              titulo: 'Fotos',
              subtitulo:
                  'El frente es obligatorio. El resto ayuda a generar más confianza.',
              child: Row(
                children: [
                  for (final entry in _etiquetasFotos.entries) ...[
                    Expanded(
                      child: PhotoSlot(
                        etiqueta: entry.value,
                        archivo: _fotosNuevas[entry.key],
                        urlExistente: _fotosExistentes[entry.key],
                        requerido: entry.key == 'frente',
                        onTap: () => _elegirFoto(entry.key),
                        onQuitar: entry.key == 'frente'
                            ? null
                            : () => _quitarFoto(entry.key),
                      ),
                    ),
                    if (entry.key != _etiquetasFotos.keys.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SeccionFormulario(
              titulo: 'Datos del producto',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _tituloController,
                    decoration: const InputDecoration(labelText: 'Título'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (valor) =>
                        (valor == null || valor.trim().isEmpty)
                        ? 'Ingresá un título'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descripcionController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    validator: (valor) =>
                        (valor == null || valor.trim().isEmpty)
                        ? 'Ingresá una descripción'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _precioController,
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresá un precio';
                      }
                      final numero = double.tryParse(
                        valor.replaceAll(',', '.'),
                      );
                      if (numero == null || numero <= 0) {
                        return 'Ingresá un precio válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Categoría',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Categoria.values.map((c) {
                      final seleccionado = _categoria == c;
                      return _ChipSeleccionable(
                        etiqueta: c.etiqueta,
                        seleccionado: seleccionado,
                        onSelected: () => setState(() {
                          _categoria = c;
                          // El talle de otra categoría puede no existir en
                          // la lista de la nueva (ej.: talle de calzado vs.
                          // talle de ropa), así que se reinicia.
                          _talle = null;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Etapa / edad',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EtapaEdad.values.map((e) {
                      final seleccionado = _etapaEdad == e;
                      return _ChipSeleccionable(
                        etiqueta: e.etiqueta,
                        icono: e.icono,
                        seleccionado: seleccionado,
                        onSelected: () => setState(() => _etapaEdad = e),
                      );
                    }).toList(),
                  ),
                  if (tallesParaCategoria(_categoria) case final talles?) ...[
                    const SizedBox(height: 18),
                    SelectorConOtro(
                      valorInicial: _talle,
                      onChanged: (valor) => setState(() => _talle = valor),
                      label: 'Talle',
                      labelOtro: 'Medida en cm u otro talle',
                      opciones: talles,
                      valorOtro: talleOtroValor,
                    ),
                  ],
                  if (colorAplicaA(_categoria)) ...[
                    const SizedBox(height: 18),
                    SelectorMultipleDesplegable(
                      label: 'Color',
                      opciones: colores,
                      seleccionados: _colores,
                      onChanged: (nuevo) => setState(() {
                        _colores
                          ..clear()
                          ..addAll(nuevo);
                      }),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SeccionFormulario(
              titulo: 'Ubicación (opcional)',
              subtitulo:
                  'Ayuda a que te encuentren familias cercanas o del mismo colegio.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectorConOtro(
                    valorInicial: _colegio,
                    onChanged: (valor) => setState(() => _colegio = valor),
                    label: 'Colegio',
                    labelOtro: 'Nombre del colegio',
                    opciones: colegiosLaPlata,
                    valorOtro: colegioOtroValor,
                  ),
                  const SizedBox(height: 14),
                  SelectorConOtro(
                    valorInicial: _barrio,
                    onChanged: (valor) => setState(() => _barrio = valor),
                    label: 'Barrio',
                    labelOtro: 'Nombre del barrio',
                    opciones: barriosLaPlata,
                    valorOtro: barrioOtroValor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _publicando ? null : _publicar,
              child: _publicando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editando ? 'Guardar cambios' : 'Publicar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeccionFormulario extends StatelessWidget {
  const _SeccionFormulario({
    required this.titulo,
    required this.child,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Chip de selección con colores explícitos en ambos estados. El
/// `ChoiceChip` del tema global no alcanza acá: cuando no se selecciona un
/// color de texto a mano, el color de la etiqueta puede terminar
/// mezclándose con el fondo de la tarjeta que lo rodea (mismo problema que
/// ya se resolvió en los chips de Búsqueda fijando el color a mano).
class _ChipSeleccionable extends StatelessWidget {
  const _ChipSeleccionable({
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
    return ChoiceChip(
      avatar: icono != null ? Icon(icono, size: 18, color: colorTexto) : null,
      label: Text(etiqueta),
      labelStyle: TextStyle(color: colorTexto, fontWeight: FontWeight.w700),
      selected: seleccionado,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: seleccionado ? Colors.transparent : colorScheme.outline,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
