import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show IconData, Icons;

enum Categoria {
  ropa,
  uniformes,
  calzado,
  juguetes,
  libros,
  accesorios,
  bebe;

  String get etiqueta => switch (this) {
    Categoria.ropa => 'Ropa',
    Categoria.uniformes => 'Uniformes',
    Categoria.calzado => 'Calzado',
    Categoria.juguetes => 'Juguetes',
    Categoria.libros => 'Libros',
    Categoria.accesorios => 'Accesorios',
    Categoria.bebe => 'Bebé / Puericultura',
  };

  String get valorFirestore => name;

  static Categoria desdeFirestore(String valor) {
    return Categoria.values.firstWhere(
      (c) => c.name == valor,
      orElse: () => Categoria.ropa,
    );
  }
}

enum EtapaEdad {
  bebe,
  jardin,
  primaria,
  secundaria;

  String get etiqueta => switch (this) {
    EtapaEdad.bebe => 'Bebé (0 a 2 años)',
    EtapaEdad.jardin => 'Jardín / Inicial (3 a 5 años)',
    EtapaEdad.primaria => 'Primaria (6 a 12 años)',
    EtapaEdad.secundaria => 'Secundaria (13 a 18 años)',
  };

  IconData get icono => switch (this) {
    EtapaEdad.bebe => Icons.child_friendly_rounded,
    EtapaEdad.jardin => Icons.child_care_rounded,
    EtapaEdad.primaria => Icons.backpack_rounded,
    EtapaEdad.secundaria => Icons.school_rounded,
  };

  String get valorFirestore => name;

  static EtapaEdad desdeFirestore(String valor) {
    return EtapaEdad.values.firstWhere(
      (e) => e.name == valor,
      orElse: () => EtapaEdad.primaria,
    );
  }
}

enum EstadoPublicacion {
  disponible,
  reservado,
  vendido;

  String get valorFirestore => name;

  static EstadoPublicacion desdeFirestore(String valor) {
    return EstadoPublicacion.values.firstWhere(
      (e) => e.name == valor,
      orElse: () => EstadoPublicacion.disponible,
    );
  }
}

class FotosPublicacion {
  const FotosPublicacion({
    required this.frente,
    this.dorso,
    this.etiqueta,
    this.detalle,
  });

  /// Única foto obligatoria. El resto ayuda a generar confianza pero no
  /// bloquea la publicación si el vendedor no las carga.
  final String frente;
  final String? dorso;
  final String? etiqueta;
  final String? detalle;

  Map<String, dynamic> toFirestore() => {
    'frente': frente,
    if (dorso != null) 'dorso': dorso,
    if (etiqueta != null) 'etiqueta': etiqueta,
    if (detalle != null) 'detalle': detalle,
  };

  factory FotosPublicacion.fromFirestore(Map<String, dynamic> data) {
    return FotosPublicacion(
      frente: data['frente'] as String? ?? '',
      dorso: data['dorso'] as String?,
      etiqueta: data['etiqueta'] as String?,
      detalle: data['detalle'] as String?,
    );
  }
}

class Publicacion {
  const Publicacion({
    required this.id,
    required this.vendedorId,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.etapaEdad,
    required this.precio,
    required this.fotos,
    this.colegio,
    this.barrio,
    this.talle,
    this.colores = const [],
    this.estado = EstadoPublicacion.disponible,
    this.fechaPublicacion,
    this.vistas = 0,
  });

  final String id;
  final String vendedorId;
  final String titulo;
  final String descripcion;
  final Categoria categoria;
  final EtapaEdad etapaEdad;
  final double precio;
  final FotosPublicacion fotos;
  final String? colegio;
  final String? barrio;
  final String? talle;

  /// Una prenda puede tener más de un color (ej. una remera a rayas), por
  /// eso es una lista y no un solo valor — y así también se puede buscar
  /// por "cualquiera de estos colores" en vez de uno exacto.
  final List<String> colores;
  final EstadoPublicacion estado;
  final DateTime? fechaPublicacion;
  final int vistas;

  Map<String, dynamic> toFirestore() {
    return {
      'vendedorId': vendedorId,
      'titulo': titulo,
      'descripcion': descripcion,
      'categoria': categoria.valorFirestore,
      'etapaEdad': etapaEdad.valorFirestore,
      'precio': precio,
      'fotos': fotos.toFirestore(),
      'colegio': colegio,
      'barrio': barrio,
      'talle': talle,
      'colores': colores,
      'estado': estado.valorFirestore,
      'vistas': vistas,
    };
  }

  factory Publicacion.fromFirestore(String id, Map<String, dynamic> data) {
    final fechaRaw = data['fechaPublicacion'];
    return Publicacion(
      id: id,
      vendedorId: data['vendedorId'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      categoria: Categoria.desdeFirestore(data['categoria'] as String? ?? ''),
      etapaEdad: EtapaEdad.desdeFirestore(data['etapaEdad'] as String? ?? ''),
      precio: (data['precio'] as num?)?.toDouble() ?? 0,
      fotos: FotosPublicacion.fromFirestore(
        Map<String, dynamic>.from(data['fotos'] as Map? ?? {}),
      ),
      colegio: data['colegio'] as String?,
      barrio: data['barrio'] as String?,
      talle: data['talle'] as String?,
      colores: (data['colores'] as List?)?.cast<String>() ?? const [],
      estado: EstadoPublicacion.desdeFirestore(
        data['estado'] as String? ?? 'disponible',
      ),
      fechaPublicacion: fechaRaw is Timestamp ? fechaRaw.toDate() : null,
      vistas: (data['vistas'] as num?)?.toInt() ?? 0,
    );
  }
}
