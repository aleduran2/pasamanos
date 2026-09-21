import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/publicacion.dart';

abstract class PublicacionRepository {
  /// Genera un ID nuevo sin escribir nada todavía — se usa para subir las
  /// fotos a Storage bajo ese ID antes de crear el documento definitivo.
  String generarId();

  Future<void> guardar(Publicacion publicacion);

  /// Edita una publicación existente: no toca `estado`, `vistas` ni
  /// `fechaPublicacion` — esos los maneja cada flujo correspondiente
  /// (cerrar acuerdo, contar vistas, la creación), no una edición.
  Future<void> actualizar(Publicacion publicacion);

  Future<void> eliminar(String id);

  Future<Publicacion?> obtenerPorId(String id);

  /// Suma una vista a la publicación. Se llama al abrir el detalle; falla
  /// en silencio si la publicación ya no existe, para no romper la
  /// experiencia de ver un producto por un error de conteo.
  Future<void> registrarVista(String id);

  Future<List<Publicacion>> listarPorVendedor(String vendedorId);

  /// Busca publicaciones disponibles. La etapa/edad es el filtro principal
  /// (obligatorio); el resto son filtros secundarios opcionales. Talle y
  /// colores solo tienen sentido junto con una categoría elegida (cada
  /// categoría usa su propio sistema de talles). `colores` es "cualquiera
  /// de estos" (OR), no una coincidencia exacta.
  Future<List<Publicacion>> buscarDisponibles({
    required EtapaEdad etapaEdad,
    Categoria? categoria,
    String? colegio,
    String? barrio,
    String? talle,
    List<String>? colores,
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
  Future<void> actualizar(Publicacion publicacion) async {
    final datos = publicacion.toFirestore()
      ..remove('estado')
      ..remove('vistas');
    await _publicacionesRef.doc(publicacion.id).update(datos);
  }

  @override
  Future<void> eliminar(String id) async {
    await _publicacionesRef.doc(id).delete();
  }

  @override
  Future<Publicacion?> obtenerPorId(String id) async {
    final snapshot = await _publicacionesRef.doc(id).get();
    if (!snapshot.exists) return null;
    return Publicacion.fromFirestore(id, snapshot.data()!);
  }

  @override
  Future<void> registrarVista(String id) async {
    try {
      await _publicacionesRef.doc(id).update({'vistas': FieldValue.increment(1)});
    } catch (_) {
      // No se pudo sumar la vista (p. ej. la publicación ya no existe);
      // no debe interrumpir la navegación del comprador.
    }
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
    publicaciones.sort(_porFechaDescendente);
    return publicaciones;
  }

  @override
  Future<List<Publicacion>> buscarDisponibles({
    required EtapaEdad etapaEdad,
    Categoria? categoria,
    String? colegio,
    String? barrio,
    String? talle,
    List<String>? colores,
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
    if (talle != null && talle.trim().isNotEmpty) {
      query = query.where('talle', isEqualTo: talle.trim());
    }
    if (colores != null && colores.isNotEmpty) {
      // "cualquiera de estos colores" — Firestore soporta hasta 30 valores.
      query = query.where('colores', arrayContainsAny: colores);
    }

    final snapshot = await query.get();
    final publicaciones = snapshot.docs
        .map((doc) => Publicacion.fromFirestore(doc.id, doc.data()))
        .toList();

    // Se ordena del lado del cliente (no en la query) para no requerir un
    // índice compuesto en Firestore por cada combinación de filtros.
    publicaciones.sort(_porFechaDescendente);
    return publicaciones;
  }
}

/// Más nueva primero. Una publicación recién creada puede leerse con
/// `fechaPublicacion` todavía sin resolver (el `serverTimestamp()` pendiente
/// llega como `null` hasta que el servidor lo confirma) — tratarla como
/// "la más nueva" en vez de "empatada" evita que quede en cualquier lugar
/// impredecible de la lista justo después de publicar.
int _porFechaDescendente(Publicacion a, Publicacion b) {
  final fechaA = a.fechaPublicacion;
  final fechaB = b.fechaPublicacion;
  if (fechaA == null && fechaB == null) return 0;
  if (fechaA == null) return -1;
  if (fechaB == null) return 1;
  return fechaB.compareTo(fechaA);
}
