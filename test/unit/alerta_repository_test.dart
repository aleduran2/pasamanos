import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/features/alertas/data/alerta_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreAlertaRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreAlertaRepository(firestore: firestore);
  });

  test('crear guarda categoría y talle, y aparece en misAlertas', () async {
    await repository.crear(
      uid: 'uid-compradora',
      categoria: Categoria.uniformes,
      talle: '8 años',
    );

    final alertas = await repository.misAlertas('uid-compradora').first;
    expect(alertas, hasLength(1));
    expect(alertas.first.categoria, Categoria.uniformes);
    expect(alertas.first.talle, '8 años');
  });

  test('crear la misma alerta dos veces no la duplica', () async {
    await repository.crear(
      uid: 'uid-compradora',
      categoria: Categoria.calzado,
      talle: '30',
    );
    await repository.crear(
      uid: 'uid-compradora',
      categoria: Categoria.calzado,
      talle: '30',
    );

    final alertas = await repository.misAlertas('uid-compradora').first;
    expect(alertas, hasLength(1));
  });

  test('misAlertas solo devuelve las de esa usuaria', () async {
    await repository.crear(
      uid: 'uid-compradora',
      categoria: Categoria.uniformes,
      talle: '8 años',
    );
    await repository.crear(
      uid: 'otra-uid',
      categoria: Categoria.uniformes,
      talle: '10 años',
    );

    final alertas = await repository.misAlertas('uid-compradora').first;
    expect(alertas, hasLength(1));
    expect(alertas.first.uid, 'uid-compradora');
  });

  test('eliminar borra la alerta', () async {
    await repository.crear(
      uid: 'uid-compradora',
      categoria: Categoria.uniformes,
      talle: '8 años',
    );
    final alertas = await repository.misAlertas('uid-compradora').first;

    await repository.eliminar(alertas.first.id);

    final alertasDespues = await repository.misAlertas('uid-compradora').first;
    expect(alertasDespues, isEmpty);
  });
}
