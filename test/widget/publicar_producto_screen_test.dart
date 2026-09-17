import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';
import 'package:pasamanos/features/catalogo/data/publicacion_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';
import 'package:pasamanos/features/catalogo/presentation/publicar_producto_screen.dart';
import 'package:pasamanos/features/catalogo/providers/catalogo_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockPublicacionRepository extends Mock implements PublicacionRepository {}

class _PublicacionFalsa extends Fake implements Publicacion {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _MockAuthRepository mockAuthRepository;
  late _MockPublicacionRepository mockPublicacionRepository;

  const usuario = AppUser(uid: 'uid-1', email: 'vendedora@example.com');

  setUpAll(() {
    registerFallbackValue(_PublicacionFalsa());
  });

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
    mockPublicacionRepository = _MockPublicacionRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(usuario);
  });

  Future<void> pumpPantalla(WidgetTester tester) async {
    // El formulario completo (4 fotos + campos + dropdowns) es más alto que
    // el viewport de test por defecto, así que el ListView no llega a
    // construir el botón "Publicar" (renderizado perezoso). Agrandamos la
    // superficie de test para que todo entre sin necesidad de scrollear.
    await binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          publicacionRepositoryProvider.overrideWithValue(
            mockPublicacionRepository,
          ),
        ],
        child: const MaterialApp(home: PublicarProductoScreen()),
      ),
    );
  }

  testWidgets('muestra errores de validación si los campos están vacíos', (
    tester,
  ) async {
    await pumpPantalla(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Publicar'));
    await tester.pump();

    expect(find.text('Ingresá un título'), findsOneWidget);
    expect(find.text('Ingresá una descripción'), findsOneWidget);
    expect(find.text('Ingresá un precio'), findsOneWidget);
    verifyNever(() => mockPublicacionRepository.guardar(any()));
  });

  testWidgets(
    'avisa si falta la foto de frente aunque los campos estén completos',
    (tester) async {
      await pumpPantalla(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título'),
        'Guardapolvo talle 8',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Usado, buen estado',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio'),
        '5000',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Publicar'));
      await tester.pump();

      expect(find.textContaining('Falta la foto de frente'), findsOneWidget);
      verifyNever(() => mockPublicacionRepository.guardar(any()));
    },
  );
}
