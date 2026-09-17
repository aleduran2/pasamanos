import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/features/perfil/data/user_profile_repository.dart';
import 'package:pasamanos/features/perfil/models/user_profile.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreUserProfileRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreUserProfileRepository(firestore: firestore);
  });

  test('crearSiNoExiste crea el perfil con valores por defecto', () async {
    final perfil = await repository.crearSiNoExiste(
      uid: 'uid-1',
      nombre: 'Juana Pérez',
      email: 'juana@example.com',
    );

    expect(perfil.uid, 'uid-1');
    expect(perfil.nombre, 'Juana Pérez');
    expect(perfil.estadoVerificacion, EstadoVerificacion.noVerificado);
    expect(perfil.calificacionPromedio, 0);
    expect(perfil.cantidadTransacciones, 0);

    final doc = await firestore.collection('users').doc('uid-1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['fechaRegistro'], isA<Timestamp>());
  });

  test('crearSiNoExiste no pisa un perfil ya existente', () async {
    await firestore.collection('users').doc('uid-1').set({
      'nombre': 'Nombre original',
      'email': 'original@example.com',
      'estadoVerificacion': 'verificado',
      'calificacionPromedio': 4.5,
      'cantidadTransacciones': 3,
    });

    final perfil = await repository.crearSiNoExiste(
      uid: 'uid-1',
      nombre: 'Otro nombre',
      email: 'otro@example.com',
    );

    expect(perfil.nombre, 'Nombre original');
    expect(perfil.estadoVerificacion, EstadoVerificacion.verificado);
    expect(perfil.calificacionPromedio, 4.5);
  });

  test('obtenerPorId devuelve null si no existe', () async {
    final perfil = await repository.obtenerPorId('no-existe');
    expect(perfil, isNull);
  });
}
