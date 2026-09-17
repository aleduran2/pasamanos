import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/publicacion.dart';
import '../providers/catalogo_providers.dart';
import 'photo_slot.dart';

const _etiquetasFotos = {
  'frente': 'Frente',
  'dorso': 'Dorso (opcional)',
  'etiqueta': 'Etiqueta (opcional)',
  'detalle': 'Detalle (opcional)',
};

class PublicarProductoScreen extends ConsumerStatefulWidget {
  const PublicarProductoScreen({super.key});

  @override
  ConsumerState<PublicarProductoScreen> createState() =>
      _PublicarProductoScreenState();
}

class _PublicarProductoScreenState
    extends ConsumerState<PublicarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  final _colegioController = TextEditingController();
  final _barrioController = TextEditingController();

  final Map<String, File?> _fotos = {
    'frente': null,
    'dorso': null,
    'etiqueta': null,
    'detalle': null,
  };

  Categoria _categoria = Categoria.ropa;
  EtapaEdad _etapaEdad = EtapaEdad.primaria;
  bool _publicando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _colegioController.dispose();
    _barrioController.dispose();
    super.dispose();
  }

  bool get _faltaFoto => _fotos['frente'] == null;

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

    setState(() => _fotos[slot] = File(archivo.path));
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_faltaFoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta la foto de frente.')),
      );
      return;
    }

    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    setState(() => _publicando = true);
    try {
      final repositorio = ref.read(publicacionRepositoryProvider);
      final subidor = ref.read(imageUploadServiceProvider);
      final id = repositorio.generarId();

      final urls = <String, String>{};
      for (final entry in _fotos.entries) {
        final archivo = entry.value;
        if (archivo == null) continue;
        urls[entry.key] = await subidor.subir(
          archivo: archivo,
          vendedorId: usuario.uid,
          publicacionId: id,
          nombreArchivo: entry.key,
        );
      }

      final publicacion = Publicacion(
        id: id,
        vendedorId: usuario.uid,
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
        colegio: _colegioController.text.trim().isEmpty
            ? null
            : _colegioController.text.trim(),
        barrio: _barrioController.text.trim().isEmpty
            ? null
            : _barrioController.text.trim(),
      );

      await repositorio.guardar(publicacion);

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo publicar. Intentá de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar producto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _etiquetasFotos.entries
                    .map(
                      (entry) => PhotoSlot(
                        etiqueta: entry.value,
                        archivo: _fotos[entry.key],
                        onTap: () => _elegirFoto(entry.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (valor) =>
                    (valor == null || valor.trim().isEmpty)
                        ? 'Ingresá un título'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (valor) =>
                    (valor == null || valor.trim().isEmpty)
                        ? 'Ingresá una descripción'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precioController,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'Ingresá un precio';
                  }
                  final numero = double.tryParse(valor.replaceAll(',', '.'));
                  if (numero == null || numero <= 0) {
                    return 'Ingresá un precio válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Categoria>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: Categoria.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.etiqueta)),
                    )
                    .toList(),
                onChanged: (valor) =>
                    setState(() => _categoria = valor ?? _categoria),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EtapaEdad>(
                initialValue: _etapaEdad,
                decoration: const InputDecoration(labelText: 'Etapa / edad'),
                items: EtapaEdad.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.etiqueta)),
                    )
                    .toList(),
                onChanged: (valor) =>
                    setState(() => _etapaEdad = valor ?? _etapaEdad),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colegioController,
                decoration: const InputDecoration(
                  labelText: 'Colegio (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barrioController,
                decoration: const InputDecoration(
                  labelText: 'Barrio (opcional)',
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
                    : const Text('Publicar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
