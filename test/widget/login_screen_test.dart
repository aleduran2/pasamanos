import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/presentation/login_screen.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
  }

  testWidgets('muestra errores de validación si los campos están vacíos', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();

    expect(find.text('Ingresá un email válido'), findsOneWidget);
    expect(
      find.text('La contraseña debe tener al menos 6 caracteres'),
      findsOneWidget,
    );
    verifyNever(
      () => mockAuthRepository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('llama a signInWithEmail con los datos ingresados', (
    tester,
  ) async {
    when(
      () => mockAuthRepository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const AppUser(uid: 'uid-1', email: 'juana@example.com'),
    );

    await pumpLoginScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'juana@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();

    verify(
      () => mockAuthRepository.signInWithEmail(
        email: 'juana@example.com',
        password: 'secreto123',
      ),
    ).called(1);
  });

  testWidgets('muestra un mensaje de error si falla el login', (
    tester,
  ) async {
    when(
      () => mockAuthRepository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      FirebaseAuthException(code: 'wrong-password'),
    );

    await pumpLoginScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'juana@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();

    expect(find.text('La contraseña es incorrecta.'), findsOneWidget);
  });

  testWidgets('el botón de Google llama a signInWithGoogle', (tester) async {
    when(
      () => mockAuthRepository.signInWithGoogle(),
    ).thenAnswer(
      (_) async => const AppUser(uid: 'uid-2', email: 'google@example.com'),
    );

    await pumpLoginScreen(tester);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    verify(() => mockAuthRepository.signInWithGoogle()).called(1);
  });

  testWidgets(
    '"Olvidaste tu contraseña" precarga el email y llama a enviarResetContrasena',
    (tester) async {
      when(
        () => mockAuthRepository.enviarResetContrasena(any()),
      ).thenAnswer((_) async {});

      await pumpLoginScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'juana@example.com',
      );
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      // El email ya escrito en el login viene precargado en el diálogo
      // (además del que ya estaba en el campo de atrás, de ahí los dos).
      expect(find.text('juana@example.com'), findsNWidgets(2));

      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      verify(
        () => mockAuthRepository.enviarResetContrasena('juana@example.com'),
      ).called(1);
      expect(
        find.text('Te mandamos un mail a juana@example.com.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '"Olvidaste tu contraseña" valida el email antes de enviar',
    (tester) async {
      await pumpLoginScreen(tester);

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar'));
      await tester.pump();

      expect(find.text('Ingresá un email válido'), findsOneWidget);
      verifyNever(() => mockAuthRepository.enviarResetContrasena(any()));
    },
  );
}
