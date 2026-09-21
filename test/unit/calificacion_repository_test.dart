import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/features/calificaciones/data/calificacion_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreCalificacionRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreCalificacionRepository(firestore: firestore);
  });

  test('yaCalifique devuelve false si todavía no calificó', () async {
    final ya = await repository.yaCalifique(
      acuerdoId: 'acuerdo-1',
      autorId: 'uid-compradora',
    );
    expect(ya, isFalse);
  });

  test('crear guarda la calificación y yaCalifique pasa a true', () async {
    await repository.crear(
      acuerdoId: 'acuerdo-1',
      autorId: 'uid-compradora',
      destinatarioId: 'uid-vendedora',
      puntaje: 5,
      comentario: 'Todo perfecto',
    );

    final ya = await repository.yaCalifique(
      acuerdoId: 'acuerdo-1',
      autorId: 'uid-compradora',
    );
    expect(ya, isTrue);

    final doc = await firestore
        .collection('calificaciones')
        .doc('acuerdo-1_uid-compradora')
        .get();
    expect(doc.data()!['puntaje'], 5);
    expect(doc.data()!['destinatarioId'], 'uid-vendedora');
  });

  test('cada trato/autora tiene un id determinístico independiente', () async {
    await repository.crear(
      acuerdoId: 'acuerdo-1',
      autorId: 'uid-compradora',
      destinatarioId: 'uid-vendedora',
      puntaje: 4,
    );
    await repository.crear(
      acuerdoId: 'acuerdo-1',
      autorId: 'uid-vendedora',
      destinatarioId: 'uid-compradora',
      puntaje: 5,
    );

    final yaCompradora = await repository.yaCalifique(
      acuerdoId: 'acuerdo-1',
      autorId: 'uid-compradora',
    );
    final yaVendedora = await repository.yaCalifique(
      acuerdoId: 'acuerdo-1',
      autorId: 'uid-vendedora',
    );
    expect(yaCompradora, isTrue);
    expect(yaVendedora, isTrue);
  });
}
