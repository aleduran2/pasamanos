import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/features/catalogo/data/publicacion_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestorePublicacionRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestorePublicacionRepository(firestore: firestore);
  });

  Publicacion construirPublicacion(String id) {
    return Publicacion(
      id: id,
      vendedorId: 'uid-vendedora',
      titulo: 'Guardapolvo talle 8',
      descripcion: 'Usado, buen estado',
      categoria: Categoria.uniformes,
      etapaEdad: EtapaEdad.primaria,
      precio: 5000,
      fotos: const FotosPublicacion(
        frente: 'https://example.com/frente.jpg',
        dorso: 'https://example.com/dorso.jpg',
        etiqueta: 'https://example.com/etiqueta.jpg',
        detalle: 'https://example.com/detalle.jpg',
      ),
      colegio: 'Colegio San Martín',
    );
  }

  test('generarId devuelve IDs distintos sin escribir nada', () {
    final id1 = repository.generarId();
    final id2 = repository.generarId();
    expect(id1, isNot(equals(id2)));
  });

  test('guardar crea el documento con estado disponible por defecto', () async {
    final id = repository.generarId();
    await repository.guardar(construirPublicacion(id));

    final doc = await firestore.collection('publicaciones').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['titulo'], 'Guardapolvo talle 8');
    expect(doc.data()!['estado'], 'disponible');
    expect(doc.data()!['fechaPublicacion'], isNotNull);
  });

  test('obtenerPorId devuelve la publicación guardada', () async {
    final id = repository.generarId();
    await repository.guardar(construirPublicacion(id));

    final publicacion = await repository.obtenerPorId(id);
    expect(publicacion, isNotNull);
    expect(publicacion!.categoria, Categoria.uniformes);
    expect(publicacion.etapaEdad, EtapaEdad.primaria);
    expect(publicacion.colegio, 'Colegio San Martín');
  });

  test('obtenerPorId devuelve null si no existe', () async {
    final publicacion = await repository.obtenerPorId('no-existe');
    expect(publicacion, isNull);
  });

  test('se puede guardar y recuperar una publicación con solo la foto de frente', () async {
    final id = repository.generarId();
    await repository.guardar(
      Publicacion(
        id: id,
        vendedorId: 'uid-vendedora',
        titulo: 'Campera talle 10',
        descripcion: 'Poco uso',
        categoria: Categoria.ropa,
        etapaEdad: EtapaEdad.primaria,
        precio: 3000,
        fotos: const FotosPublicacion(frente: 'https://example.com/frente.jpg'),
      ),
    );

    final publicacion = await repository.obtenerPorId(id);
    expect(publicacion!.fotos.frente, 'https://example.com/frente.jpg');
    expect(publicacion.fotos.dorso, isNull);
    expect(publicacion.fotos.etiqueta, isNull);
    expect(publicacion.fotos.detalle, isNull);
  });

  test('listarPorVendedor devuelve solo las publicaciones de ese vendedor', () async {
    final idPropia = repository.generarId();
    await repository.guardar(construirPublicacion(idPropia));

    final idAjena = repository.generarId();
    await repository.guardar(
      Publicacion(
        id: idAjena,
        vendedorId: 'otro-uid',
        titulo: 'Otro producto',
        descripcion: 'Descripción',
        categoria: Categoria.juguetes,
        etapaEdad: EtapaEdad.bebe,
        precio: 1000,
        fotos: const FotosPublicacion(
          frente: 'a',
          dorso: 'b',
          etiqueta: 'c',
          detalle: 'd',
        ),
      ),
    );

    final publicaciones = await repository.listarPorVendedor('uid-vendedora');
    expect(publicaciones, hasLength(1));
    expect(publicaciones.first.id, idPropia);
  });

  group('buscarDisponibles', () {
    const fotos = FotosPublicacion(
      frente: 'a',
      dorso: 'b',
      etiqueta: 'c',
      detalle: 'd',
    );

    Future<void> guardarConEstado({
      required String id,
      required EtapaEdad etapaEdad,
      required Categoria categoria,
      EstadoPublicacion estado = EstadoPublicacion.disponible,
      String? colegio,
    }) {
      return repository.guardar(
        Publicacion(
          id: id,
          vendedorId: 'uid-vendedora',
          titulo: 'Producto $id',
          descripcion: 'Descripción',
          categoria: categoria,
          etapaEdad: etapaEdad,
          precio: 1000,
          fotos: fotos,
          estado: estado,
          colegio: colegio,
        ),
      );
    }

    test('filtra por etapa/edad y excluye lo no disponible', () async {
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.primaria,
        categoria: Categoria.uniformes,
      );
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.bebe,
        categoria: Categoria.ropa,
      );
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.primaria,
        categoria: Categoria.libros,
        estado: EstadoPublicacion.vendido,
      );

      final resultados = await repository.buscarDisponibles(
        etapaEdad: EtapaEdad.primaria,
      );

      expect(resultados, hasLength(1));
      expect(resultados.first.categoria, Categoria.uniformes);
    });

    test('sin etapaEdad busca en todas las etapas', () async {
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.primaria,
        categoria: Categoria.uniformes,
      );
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.bebe,
        categoria: Categoria.ropa,
      );
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.secundaria,
        categoria: Categoria.libros,
        estado: EstadoPublicacion.vendido,
      );

      final resultados = await repository.buscarDisponibles();

      expect(resultados, hasLength(2));
    });

    test('aplica el filtro secundario de categoría', () async {
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.secundaria,
        categoria: Categoria.uniformes,
      );
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.secundaria,
        categoria: Categoria.libros,
      );

      final resultados = await repository.buscarDisponibles(
        etapaEdad: EtapaEdad.secundaria,
        categoria: Categoria.libros,
      );

      expect(resultados, hasLength(1));
      expect(resultados.first.categoria, Categoria.libros);
    });

    test('aplica el filtro secundario de colegio', () async {
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.jardin,
        categoria: Categoria.uniformes,
        colegio: 'Colegio San Martín',
      );
      await guardarConEstado(
        id: repository.generarId(),
        etapaEdad: EtapaEdad.jardin,
        categoria: Categoria.uniformes,
        colegio: 'Otro colegio',
      );

      final resultados = await repository.buscarDisponibles(
        etapaEdad: EtapaEdad.jardin,
        colegio: 'Colegio San Martín',
      );

      expect(resultados, hasLength(1));
      expect(resultados.first.colegio, 'Colegio San Martín');
    });

    test('las destacadas (no vencidas) aparecen primero', () async {
      final idVieja = repository.generarId();
      await guardarConEstado(
        id: idVieja,
        etapaEdad: EtapaEdad.primaria,
        categoria: Categoria.uniformes,
      );
      final idNueva = repository.generarId();
      await guardarConEstado(
        id: idNueva,
        etapaEdad: EtapaEdad.primaria,
        categoria: Categoria.uniformes,
      );
      final idDestacadaVencida = repository.generarId();
      await guardarConEstado(
        id: idDestacadaVencida,
        etapaEdad: EtapaEdad.primaria,
        categoria: Categoria.uniformes,
      );
      // Simula lo que escribe `destacarWebhook` (admin, no pasa por el
      // repositorio del cliente): la vieja se destaca y sigue vigente, la
      // otra se había destacado pero ya venció.
      await firestore.collection('publicaciones').doc(idVieja).update({
        'destacadaHasta': DateTime.now().add(const Duration(days: 3)),
      });
      await firestore
          .collection('publicaciones')
          .doc(idDestacadaVencida)
          .update({
            'destacadaHasta': DateTime.now().subtract(const Duration(days: 1)),
          });

      final resultados = await repository.buscarDisponibles(
        etapaEdad: EtapaEdad.primaria,
      );

      expect(resultados, hasLength(3));
      expect(resultados.first.id, idVieja);
      expect(resultados.first.estaDestacada, isTrue);
      expect(
        resultados.skip(1).map((p) => p.estaDestacada),
        everyElement(isFalse),
      );
    });
  });
}
