import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';
import 'package:pasamanos/features/catalogo/data/publicacion_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';
import 'package:pasamanos/features/catalogo/presentation/mis_publicaciones_screen.dart';
import 'package:pasamanos/features/catalogo/providers/catalogo_providers.dart';
import 'package:pasamanos/features/perfil/data/mercadopago_repository.dart';
import 'package:pasamanos/features/perfil/data/user_profile_repository.dart';
import 'package:pasamanos/features/perfil/models/user_profile.dart';
import 'package:pasamanos/features/perfil/providers/perfil_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockPublicacionRepository extends Mock implements PublicacionRepository {}

class _MockUserProfileRepository extends Mock implements UserProfileRepository {}

class _MockMercadoPagoRepository extends Mock implements MercadoPagoRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;
  late _MockPublicacionRepository mockPublicacionRepository;
  late _MockUserProfileRepository mockUserProfileRepository;
  late _MockMercadoPagoRepository mockMercadoPagoRepository;

  const usuario = AppUser(
    uid: 'uid-1',
    email: 'vendedora@example.com',
    emailVerificado: true,
  );

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
    mockPublicacionRepository = _MockPublicacionRepository();
    mockUserProfileRepository = _MockUserProfileRepository();
    mockMercadoPagoRepository = _MockMercadoPagoRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(usuario);
    // Por defecto, email ya confirmado: así los tests que no les importa
    // este detalle no ven aparecer la tarjeta de onboarding por sorpresa.
    when(
      () => mockAuthRepository.refrescarUsuario(),
    ).thenAnswer((_) async => usuario);
    // Por defecto, sin perfil cargado: la tarjeta de onboarding necesita un
    // perfil no nulo para mostrarse, así que esto la mantiene oculta salvo
    // que un test puntual la pise.
    when(
      () => mockUserProfileRepository.obtenerPorId('uid-1'),
    ).thenAnswer((_) async => null);
    when(
      () => mockMercadoPagoRepository.estaConectada('uid-1'),
    ).thenAnswer((_) async => false);
  });

  Future<void> pumpPantalla(
    WidgetTester tester, {
    VoidCallback? onIrAPerfil,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          publicacionRepositoryProvider.overrideWithValue(
            mockPublicacionRepository,
          ),
          userProfileRepositoryProvider.overrideWithValue(
            mockUserProfileRepository,
          ),
          mercadoPagoRepositoryProvider.overrideWithValue(
            mockMercadoPagoRepository,
          ),
        ],
        child: MaterialApp(
          home: MisPublicacionesScreen(onIrAPerfil: onIrAPerfil ?? () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra estado vacío cuando no hay publicaciones', (
    tester,
  ) async {
    when(
      () => mockPublicacionRepository.listarPorVendedor('uid-1'),
    ).thenAnswer((_) async => []);

    await pumpPantalla(tester);

    expect(find.text('Mis publicaciones'), findsOneWidget);
    expect(find.textContaining('Todavía no publicaste nada'), findsOneWidget);
  });

  testWidgets('muestra la lista de publicaciones del vendedor', (
    tester,
  ) async {
    when(() => mockPublicacionRepository.listarPorVendedor('uid-1')).thenAnswer(
      (_) async => [
        const Publicacion(
          id: 'pub-1',
          vendedorId: 'uid-1',
          titulo: 'Guardapolvo talle 8',
          descripcion: 'Usado, buen estado',
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

    expect(find.text('Guardapolvo talle 8'), findsOneWidget);
    expect(find.text('\$ 5.000'), findsOneWidget);
  });

  testWidgets('tocar "Activas" filtra la lista a solo las disponibles', (
    tester,
  ) async {
    when(() => mockPublicacionRepository.listarPorVendedor('uid-1')).thenAnswer(
      (_) async => [
        const Publicacion(
          id: 'pub-1',
          vendedorId: 'uid-1',
          titulo: 'Guardapolvo talle 8',
          descripcion: 'Usado, buen estado',
          categoria: Categoria.uniformes,
          etapaEdad: EtapaEdad.primaria,
          precio: 5000,
          estado: EstadoPublicacion.disponible,
          fotos: FotosPublicacion(frente: 'https://example.com/frente.jpg'),
        ),
        const Publicacion(
          id: 'pub-2',
          vendedorId: 'uid-1',
          titulo: 'Campera talle 10',
          descripcion: 'Usado, buen estado',
          categoria: Categoria.ropa,
          etapaEdad: EtapaEdad.primaria,
          precio: 7000,
          estado: EstadoPublicacion.vendido,
          fotos: FotosPublicacion(frente: 'https://example.com/frente.jpg'),
        ),
      ],
    );

    await pumpPantalla(tester);

    // Antes de filtrar se ven las dos publicaciones.
    expect(find.text('Guardapolvo talle 8'), findsOneWidget);
    expect(find.text('Campera talle 10'), findsOneWidget);

    await tester.tap(find.text('Activas'));
    await tester.pumpAndSettle();

    // Filtrado: solo queda la disponible, y aparece el botón para deshacerlo.
    expect(find.text('Guardapolvo talle 8'), findsOneWidget);
    expect(find.text('Campera talle 10'), findsNothing);
    expect(find.text('Ver todas'), findsOneWidget);

    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();

    expect(find.text('Guardapolvo talle 8'), findsOneWidget);
    expect(find.text('Campera talle 10'), findsOneWidget);
  });

  testWidgets('tocar "Vistas totales" ordena la lista de más a menos vistas', (
    tester,
  ) async {
    when(() => mockPublicacionRepository.listarPorVendedor('uid-1')).thenAnswer(
      (_) async => [
        const Publicacion(
          id: 'pub-1',
          vendedorId: 'uid-1',
          titulo: 'Guardapolvo talle 8',
          descripcion: 'Usado, buen estado',
          categoria: Categoria.uniformes,
          etapaEdad: EtapaEdad.primaria,
          precio: 5000,
          vistas: 2,
          fotos: FotosPublicacion(frente: 'https://example.com/frente.jpg'),
        ),
        const Publicacion(
          id: 'pub-2',
          vendedorId: 'uid-1',
          titulo: 'Campera talle 10',
          descripcion: 'Usado, buen estado',
          categoria: Categoria.ropa,
          etapaEdad: EtapaEdad.primaria,
          precio: 7000,
          vistas: 9,
          fotos: FotosPublicacion(frente: 'https://example.com/frente.jpg'),
        ),
      ],
    );

    await pumpPantalla(tester);

    // Antes de ordenar, aparecen en el orden que las devuelve el repositorio.
    var titulos = tester
        .widgetList<Text>(find.textContaining('talle'))
        .map((t) => t.data)
        .toList();
    expect(titulos, ['Guardapolvo talle 8', 'Campera talle 10']);

    await tester.tap(find.text('Vistas totales'));
    await tester.pumpAndSettle();

    expect(find.text('Mis publicaciones, ordenadas por vistas'), findsOneWidget);
    titulos = tester
        .widgetList<Text>(find.textContaining('talle'))
        .map((t) => t.data)
        .toList();
    expect(titulos, ['Campera talle 10', 'Guardapolvo talle 8']);

    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();

    expect(find.text('Mis publicaciones'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'muestra la tarjeta de onboarding si falta verificar o conectar MP',
    (tester) async {
      when(
        () => mockUserProfileRepository.obtenerPorId('uid-1'),
      ).thenAnswer(
        (_) async => const UserProfile(
          uid: 'uid-1',
          nombre: 'Vendedora',
          email: 'vendedora@example.com',
        ),
      );
      when(
        () => mockPublicacionRepository.listarPorVendedor('uid-1'),
      ).thenAnswer((_) async => []);

      await pumpPantalla(tester);

      expect(find.text('Completá tu cuenta'), findsOneWidget);
      expect(
        find.text('Verificá tu identidad para compras protegidas'),
        findsOneWidget,
      );
      expect(
        find.text('Conectá Mercado Pago para cobrar tus ventas'),
        findsOneWidget,
      );
    },
  );

  testWidgets('no muestra la tarjeta de onboarding si ya está todo hecho', (
    tester,
  ) async {
    when(
      () => mockUserProfileRepository.obtenerPorId('uid-1'),
    ).thenAnswer(
      (_) async => const UserProfile(
        uid: 'uid-1',
        nombre: 'Vendedora',
        email: 'vendedora@example.com',
        estadoVerificacion: EstadoVerificacion.verificado,
      ),
    );
    when(
      () => mockMercadoPagoRepository.estaConectada('uid-1'),
    ).thenAnswer((_) async => true);
    when(
      () => mockPublicacionRepository.listarPorVendedor('uid-1'),
    ).thenAnswer((_) async => []);

    await pumpPantalla(tester);

    expect(find.text('Completá tu cuenta'), findsNothing);
  });

  testWidgets('cerrar la tarjeta de onboarding la oculta y lo guarda', (
    tester,
  ) async {
    when(
      () => mockUserProfileRepository.obtenerPorId('uid-1'),
    ).thenAnswer(
      (_) async => const UserProfile(
        uid: 'uid-1',
        nombre: 'Vendedora',
        email: 'vendedora@example.com',
      ),
    );
    when(
      () => mockUserProfileRepository.ocultarOnboarding('uid-1'),
    ).thenAnswer((_) async {});
    when(
      () => mockPublicacionRepository.listarPorVendedor('uid-1'),
    ).thenAnswer((_) async => []);

    await pumpPantalla(tester);
    expect(find.text('Completá tu cuenta'), findsOneWidget);

    await tester.tap(find.byTooltip('No volver a mostrar'));
    await tester.pumpAndSettle();

    expect(find.text('Completá tu cuenta'), findsNothing);
    verify(() => mockUserProfileRepository.ocultarOnboarding('uid-1')).called(1);
  });

  testWidgets(
    'muestra "Confirmá tu email" si todavía no lo confirmó, y se puede reenviar',
    (tester) async {
      when(
        () => mockAuthRepository.refrescarUsuario(),
      ).thenAnswer((_) async => const AppUser(
        uid: 'uid-1',
        email: 'vendedora@example.com',
        emailVerificado: false,
      ));
      when(
        () => mockAuthRepository.reenviarVerificacionEmail(),
      ).thenAnswer((_) async {});
      when(
        () => mockUserProfileRepository.obtenerPorId('uid-1'),
      ).thenAnswer(
        (_) async => const UserProfile(
          uid: 'uid-1',
          nombre: 'Vendedora',
          email: 'vendedora@example.com',
          estadoVerificacion: EstadoVerificacion.verificado,
        ),
      );
      when(
        () => mockMercadoPagoRepository.estaConectada('uid-1'),
      ).thenAnswer((_) async => true);
      when(
        () => mockPublicacionRepository.listarPorVendedor('uid-1'),
      ).thenAnswer((_) async => []);

      await pumpPantalla(tester);

      expect(find.text('Completá tu cuenta'), findsOneWidget);
      expect(find.text('Confirmá tu email'), findsOneWidget);

      await tester.tap(find.text('Confirmá tu email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reenviar email'));
      await tester.pumpAndSettle();

      verify(() => mockAuthRepository.reenviarVerificacionEmail()).called(1);
      expect(find.text('Te volvimos a mandar el mail.'), findsOneWidget);
    },
  );

  testWidgets(
    'tocar "Verificá tu identidad" en el onboarding llama a onIrAPerfil',
    (tester) async {
      when(
        () => mockUserProfileRepository.obtenerPorId('uid-1'),
      ).thenAnswer(
        (_) async => const UserProfile(
          uid: 'uid-1',
          nombre: 'Vendedora',
          email: 'vendedora@example.com',
        ),
      );
      when(
        () => mockPublicacionRepository.listarPorVendedor('uid-1'),
      ).thenAnswer((_) async => []);

      var llamado = false;
      await pumpPantalla(tester, onIrAPerfil: () => llamado = true);

      await tester.tap(find.text('Verificá tu identidad para compras protegidas'));
      await tester.pumpAndSettle();

      expect(llamado, isTrue);
    },
  );
}
