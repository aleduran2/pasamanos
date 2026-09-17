import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/presentation/register_screen.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
  });

  Future<void> pumpRegisterScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
  }

  testWidgets('muestra errores de validación si los campos están vacíos', (
    tester,
  ) async {
    await pumpRegisterScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Ingresá tu nombre'), findsOneWidget);
    expect(find.text('Ingresá un email válido'), findsOneWidget);
    expect(
      find.text('La contraseña debe tener al menos 6 caracteres'),
      findsOneWidget,
    );
  });

  testWidgets('llama a registerWithEmail con los datos ingresados', (
    tester,
  ) async {
    when(
      () => mockAuthRepository.registerWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
        nombre: any(named: 'nombre'),
      ),
    ).thenAnswer(
      (_) async => const AppUser(
        uid: 'uid-1',
        email: 'juana@example.com',
        nombre: 'Juana Pérez',
      ),
    );

    await pumpRegisterScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Juana Pérez',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'juana@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    verify(
      () => mockAuthRepository.registerWithEmail(
        email: 'juana@example.com',
        password: 'secreto123',
        nombre: 'Juana Pérez',
      ),
    ).called(1);
  });

  testWidgets('muestra un mensaje de error si el email ya existe', (
    tester,
  ) async {
    when(
      () => mockAuthRepository.registerWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
        nombre: any(named: 'nombre'),
      ),
    ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

    await pumpRegisterScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Juana Pérez',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'juana@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Ya existe una cuenta con ese email.'), findsOneWidget);
  });
}
