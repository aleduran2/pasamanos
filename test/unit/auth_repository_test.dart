import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/perfil/data/user_profile_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  test('registerWithEmail crea el usuario y su perfil en Firestore', () async {
    final auth = MockFirebaseAuth();
    final repository = FirebaseAuthRepository(
      firebaseAuth: auth,
      userProfileRepository: FirestoreUserProfileRepository(
        firestore: firestore,
      ),
    );

    final usuario = await repository.registerWithEmail(
      email: 'juana@example.com',
      password: 'secreto123',
      nombre: 'Juana Pérez',
    );

    expect(usuario.email, 'juana@example.com');
    expect(usuario.nombre, 'Juana Pérez');

    final doc = await firestore.collection('users').doc(usuario.uid).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['nombre'], 'Juana Pérez');
    expect(doc.data()!['email'], 'juana@example.com');
  });

  test('signInWithEmail mapea el usuario autenticado a AppUser', () async {
    final mockUser = MockUser(
      uid: 'uid-existente',
      email: 'existente@example.com',
      displayName: 'Usuario Existente',
    );
    final auth = MockFirebaseAuth(mockUser: mockUser);
    final repository = FirebaseAuthRepository(
      firebaseAuth: auth,
      userProfileRepository: FirestoreUserProfileRepository(
        firestore: firestore,
      ),
    );

    final usuario = await repository.signInWithEmail(
      email: 'existente@example.com',
      password: 'cualquiera',
    );

    expect(usuario.uid, 'uid-existente');
    expect(usuario.email, 'existente@example.com');
    expect(usuario.nombre, 'Usuario Existente');
  });

  test('authStateChanges refleja el usuario actual', () async {
    final auth = MockFirebaseAuth(signedIn: false);
    final repository = FirebaseAuthRepository(
      firebaseAuth: auth,
      userProfileRepository: FirestoreUserProfileRepository(
        firestore: firestore,
      ),
    );

    expect(repository.currentUser, isNull);

    // MockFirebaseAuth emite un evento null al construirse (antes de que
    // nos suscribamos), así que saltamos ese primer evento y esperamos
    // el que corresponde al registro.
    final proximoEvento = repository.authStateChanges.skip(1).first;

    await repository.registerWithEmail(
      email: 'nueva@example.com',
      password: 'secreto123',
      nombre: 'Nueva Usuaria',
    );

    final usuario = await proximoEvento;
    expect(usuario?.email, 'nueva@example.com');
  });

  test('signOut limpia la sesión', () async {
    final mockUser = MockUser(uid: 'uid-1', email: 'a@example.com');
    final auth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
    final repository = FirebaseAuthRepository(
      firebaseAuth: auth,
      userProfileRepository: FirestoreUserProfileRepository(
        firestore: firestore,
      ),
    );

    expect(repository.currentUser, isNotNull);
    await repository.signOut();
    expect(repository.currentUser, isNull);
  });
}
