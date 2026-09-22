import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';
import 'package:pasamanos/features/busqueda/presentation/busqueda_screen.dart';
import 'package:pasamanos/features/catalogo/data/publicacion_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';
import 'package:pasamanos/features/catalogo/providers/catalogo_providers.dart';

class _MockPublicacionRepository extends Mock implements PublicacionRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPublicacionRepository mockPublicacionRepository;
  late _MockAuthRepository mockAuthRepository;

  setUpAll(() {
    registerFallbackValue(EtapaEdad.bebe);
    registerFallbackValue(Categoria.ropa);
  });

  setUp(() {
    mockPublicacionRepository = _MockPublicacionRepository();
    mockAuthRepository = _MockAuthRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(null);
  });

  Future<void> pumpPantalla(WidgetTester tester) async {
    // Con "Más filtros" desplegado, el contenido es más alto que el
    // viewport de test por defecto — el botón "Aplicar filtros" quedaría
    // fuera de los límites de la superficie y `tap()` fallaría el hit
    // test aunque `ensureVisible` lo haya scrolleado.
    await binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicacionRepositoryProvider.overrideWithValue(
            mockPublicacionRepository,
          ),
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: const MaterialApp(home: BusquedaScreen()),
      ),
    );
  }

  testWidgets('pide elegir una etapa antes de mostrar resultados', (
    tester,
  ) async {
    await pumpPantalla(tester);

    expect(
      find.textContaining('Elegí una etapa/edad'),
      findsOneWidget,
    );
    verifyNever(
      () => mockPublicacionRepository.buscarDisponibles(
        etapaEdad: any(named: 'etapaEdad'),
      ),
    );
  });

  testWidgets('al elegir una etapa busca y muestra resultados', (
    tester,
  ) async {
    when(
      () => mockPublicacionRepository.buscarDisponibles(
        etapaEdad: EtapaEdad.primaria,
        categoria: any(named: 'categoria'),
        colegio: any(named: 'colegio'),
        barrio: any(named: 'barrio'),
        talle: any(named: 'talle'),
        colores: any(named: 'colores'),
      ),
    ).thenAnswer(
      (_) async => [
        const Publicacion(
          id: 'pub-1',
          vendedorId: 'uid-1',
          titulo: 'Guardapolvo talle 8',
          descripcion: 'Usado',
          categoria: Categoria.uniformes,
          etapaEdad: EtapaEdad.primaria,
          precio: 5000,
          fotos: FotosPublicacion(
            frente: 'https://example.com/frente.jpg',
            dorso: 'https://example.com/dorso.jpg',
            etiqueta: 'https://example.com/etiqueta.jpg',
            detalle: 'https://example.com/detalle.jpg',
          ),
        ),
      ],
    );

    await pumpPantalla(tester);

    await tester.tap(find.text('Primaria (6 a 12 años)'));
    await tester.pumpAndSettle();

    expect(find.text('Guardapolvo talle 8'), findsOneWidget);
  });

  testWidgets(
    '"Aplicar filtros" sin etapa elegida busca en todas las etapas',
    (tester) async {
      when(
        () => mockPublicacionRepository.buscarDisponibles(
          etapaEdad: null,
          categoria: any(named: 'categoria'),
          colegio: any(named: 'colegio'),
          barrio: any(named: 'barrio'),
          talle: any(named: 'talle'),
          colores: any(named: 'colores'),
        ),
      ).thenAnswer(
        (_) async => [
          const Publicacion(
            id: 'pub-1',
            vendedorId: 'uid-1',
            titulo: 'Producto de cualquier etapa',
            descripcion: 'Usado',
            categoria: Categoria.uniformes,
            etapaEdad: EtapaEdad.primaria,
            precio: 5000,
            fotos: FotosPublicacion(
              frente: 'https://example.com/frente.jpg',
              dorso: 'https://example.com/dorso.jpg',
              etiqueta: 'https://example.com/etiqueta.jpg',
              detalle: 'https://example.com/detalle.jpg',
            ),
          ),
        ],
      );

      await pumpPantalla(tester);

      await tester.tap(find.text('Más filtros'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Aplicar filtros'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Producto de cualquier etapa'), findsOneWidget);
    },
  );

  testWidgets('"Más filtros" despliega la categoría y el resto de filtros', (
    tester,
  ) async {
    await pumpPantalla(tester);

    expect(find.text('Categoría'), findsNothing);

    await tester.tap(find.text('Más filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Precio'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
  });

  testWidgets('muestra estado vacío si no hay resultados', (tester) async {
    when(
      () => mockPublicacionRepository.buscarDisponibles(
        etapaEdad: EtapaEdad.bebe,
        categoria: any(named: 'categoria'),
        colegio: any(named: 'colegio'),
        barrio: any(named: 'barrio'),
        talle: any(named: 'talle'),
        colores: any(named: 'colores'),
      ),
    ).thenAnswer((_) async => []);

    await pumpPantalla(tester);

    await tester.tap(find.text('Bebé (0 a 2 años)'));
    await tester.pumpAndSettle();

    expect(
      find.text('No encontramos productos con esos filtros.'),
      findsOneWidget,
    );
  });
}
