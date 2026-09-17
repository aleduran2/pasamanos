import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/publicacion.dart';

abstract class PublicacionRepository {
  /// Genera un ID nuevo sin escribir nada todavía — se usa para subir las
  /// fotos a Storage bajo ese ID antes de crear el documento definitivo.
  String generarId();

  Future<void> guardar(Publicacion publicacion);

  Future<Publicacion?> obtenerPorId(String id);

  Future<List<Publicacion>> listarPorVendedor(String vendedorId);

  /// Busca publicaciones disponibles. La etapa/edad es el filtro principal
  /// (obligatorio); categoría, colegio y barrio son filtros secundarios
  /// opcionales.
  Future<List<Publicacion>> buscarDisponibles({
    required EtapaEdad etapaEdad,
    Categoria? categoria,
    String? colegio,
    String? barrio,
  });
}

class FirestorePublicacionRepository implements PublicacionRepository {
  FirestorePublicacionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _publicacionesRef =>
      _firestore.collection('publicaciones');

  @override
  String generarId() => _publicacionesRef.doc().id;

  @override
  Future<void> guardar(Publicacion publicacion) async {
    await _publicacionesRef.doc(publicacion.id).set({
      ...publicacion.toFirestore(),
      'fechaPublicacion': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Publicacion?> obtenerPorId(String id) async {
    final snapshot = await _publicacionesRef.doc(id).get();
    if (!snapshot.exists) return null;
    return Publicacion.fromFirestore(id, snapshot.data()!);
  }

  @override
  Future<List<Publicacion>> listarPorVendedor(String vendedorId) async {
    final snapshot = await _publicacionesRef
        .where('vendedorId', isEqualTo: vendedorId)
        .get();
    final publicaciones = snapshot.docs
        .map((doc) => Publicacion.fromFirestore(doc.id, doc.data()))
        .toList();

    // Se ordena del lado del cliente (no en la query) para no requerir un
    // índice compuesto en Firestore, igual que en buscarDisponibles.
    publicaciones.sort((a, b) {
      final fechaA = a.fechaPublicacion;
      final fechaB = b.fechaPublicacion;
      if (fechaA == null || fechaB == null) return 0;
      return fechaB.compareTo(fechaA);
    });
    return publicaciones;
  }

  @override
  Future<List<Publicacion>> buscarDisponibles({
    required EtapaEdad etapaEdad,
    Categoria? categoria,
    String? colegio,
    String? barrio,
  }) async {
    Query<Map<String, dynamic>> query = _publicacionesRef
        .where('estado', isEqualTo: EstadoPublicacion.disponible.valorFirestore)
        .where('etapaEdad', isEqualTo: etapaEdad.valorFirestore);

    if (categoria != null) {
      query = query.where('categoria', isEqualTo: categoria.valorFirestore);
    }
    if (colegio != null && colegio.trim().isNotEmpty) {
      query = query.where('colegio', isEqualTo: colegio.trim());
    }
    if (barrio != null && barrio.trim().isNotEmpty) {
      query = query.where('barrio', isEqualTo: barrio.trim());
    }

    final snapshot = await query.get();
    final publicaciones = snapshot.docs
        .map((doc) => Publicacion.fromFirestore(doc.id, doc.data()))
        .toList();

    // Se ordena del lado del cliente (no en la query) para no requerir un
    // índice compuesto en Firestore por cada combinación de filtros.
    publicaciones.sort((a, b) {
      final fechaA = a.fechaPublicacion;
      final fechaB = b.fechaPublicacion;
      if (fechaA == null || fechaB == null) return 0;
      return fechaB.compareTo(fechaA);
    });
    return publicaciones;
  }
}
