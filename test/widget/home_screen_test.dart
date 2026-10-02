import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';
import 'package:pasamanos/features/catalogo/data/publicacion_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';
import 'package:pasamanos/features/catalogo/providers/catalogo_providers.dart';
import 'package:pasamanos/features/chat/data/chat_repository.dart';
import 'package:pasamanos/features/chat/providers/chat_providers.dart';
import 'package:pasamanos/features/home/presentation/home_screen.dart';
import 'package:pasamanos/features/notificaciones/data/fcm_token_service.dart';
import 'package:pasamanos/features/notificaciones/providers/notificaciones_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockPublicacionRepository extends Mock implements PublicacionRepository {}

class _MockFcmTokenService extends Mock implements FcmTokenService {}

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;
  late _MockPublicacionRepository mockPublicacionRepository;
  late _MockFcmTokenService mockFcmTokenService;
  late _MockChatRepository mockChatRepository;

  const usuario = AppUser(uid: 'uid-1', email: 'vendedora@example.com');

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
    mockPublicacionRepository = _MockPublicacionRepository();
    mockFcmTokenService = _MockFcmTokenService();
    mockChatRepository = _MockChatRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(usuario);
    when(
      () => mockFcmTokenService.registrarToken(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockChatRepository.misConversaciones('uid-1'),
    ).thenAnswer((_) => Stream.value(const []));
  });

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          publicacionRepositoryProvider.overrideWithValue(
            mockPublicacionRepository,
          ),
          fcmTokenServiceProvider.overrideWithValue(mockFcmTokenService),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
        child: const MaterialApp(home: HomeScreen()),
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

    await pumpHomeScreen(tester);

    expect(find.text('Pasamanos'), findsOneWidget);
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

    await pumpHomeScreen(tester);

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

    await pumpHomeScreen(tester);

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

  testWidgets('tocar el ícono de info de "Vistas totales" explica qué es', (
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
          vistas: 3,
          fotos: FotosPublicacion(frente: 'https://example.com/frente.jpg'),
        ),
      ],
    );

    await pumpHomeScreen(tester);

    expect(find.text('Vistas totales'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Entendido'), findsOneWidget);
    expect(find.textContaining('entraron a ver el detalle'), findsOneWidget);
  });
}
