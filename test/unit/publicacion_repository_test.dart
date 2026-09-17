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
}
