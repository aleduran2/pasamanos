import 'package:cloud_firestore/cloud_firestore.dart';

import '../../catalogo/models/publicacion.dart';

/// Aviso guardado por una usuaria para enterarse apenas se publique un
/// producto de esta categoría (+ talle, si la categoría usa talles — la
/// combinación de categoría y talle es lo que de verdad identifica qué
/// talle es, porque el mismo string de talle significa cosas distintas en
/// ropa que en calzado). Para categorías sin talle (accesorios, juguetes,
/// libros, bebé), `talle` queda en null y la alerta es "avisame de
/// cualquier producto nuevo de esta categoría".
class Alerta {
  const Alerta({
    required this.id,
    required this.uid,
    required this.categoria,
    this.talle,
    this.fechaCreacion,
  });

  final String id;
  final String uid;
  final Categoria categoria;
  final String? talle;
  final DateTime? fechaCreacion;

  factory Alerta.fromFirestore(String id, Map<String, dynamic> data) {
    final fechaRaw = data['fechaCreacion'];
    return Alerta(
      id: id,
      uid: data['uid'] as String? ?? '',
      categoria: Categoria.desdeFirestore(data['categoria'] as String? ?? ''),
      talle: data['talle'] as String?,
      fechaCreacion: fechaRaw is Timestamp ? fechaRaw.toDate() : null,
    );
  }
}
