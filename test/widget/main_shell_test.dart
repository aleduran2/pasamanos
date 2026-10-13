import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:pasamanos/features/favoritos/data/favorito_repository.dart';
import 'package:pasamanos/features/favoritos/providers/favorito_providers.dart';
import 'package:pasamanos/features/home/presentation/main_shell.dart';
import 'package:pasamanos/features/notificaciones/data/fcm_token_service.dart';
import 'package:pasamanos/features/notificaciones/providers/notificaciones_providers.dart';
import 'package:pasamanos/features/perfil/data/mercadopago_repository.dart';
import 'package:pasamanos/features/perfil/data/user_profile_repository.dart';
import 'package:pasamanos/features/perfil/models/user_profile.dart';
import 'package:pasamanos/features/perfil/providers/perfil_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockPublicacionRepository extends Mock implements PublicacionRepository {}

class _MockFavoritoRepository extends Mock implements FavoritoRepository {}

class _MockUserProfileRepository extends Mock implements UserProfileRepository {}

class _MockMercadoPagoRepository extends Mock implements MercadoPagoRepository {}

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockFcmTokenService extends Mock implements FcmTokenService {}

void main() {
  late _MockAuthRepository mockAuthRepository;
  late _MockPublicacionRepository mockPublicacionRepository;
  late _MockFavoritoRepository mockFavoritoRepository;
  late _MockUserProfileRepository mockUserProfileRepository;
  late _MockMercadoPagoRepository mockMercadoPagoRepository;
  late _MockChatRepository mockChatRepository;
  late _MockFcmTokenService mockFcmTokenService;

  setUpAll(() {
    registerFallbackValue(EtapaEdad.bebe);
    registerFallbackValue(Categoria.ropa);
  });

  const usuario = AppUser(
    uid: 'uid-1',
    email: 'vendedora@example.com',
    emailVerificado: true,
  );

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
    mockPublicacionRepository = _MockPublicacionRepository();
    mockFavoritoRepository = _MockFavoritoRepository();
    mockUserProfileRepository = _MockUserProfileRepository();
    mockMercadoPagoRepository = _MockMercadoPagoRepository();
    mockChatRepository = _MockChatRepository();
    mockFcmTokenService = _MockFcmTokenService();

    when(() => mockAuthRepository.currentUser).thenReturn(usuario);
    when(() => mockAuthRepository.tieneContrasena).thenReturn(true);
    when(
      () => mockAuthRepository.refrescarUsuario(),
    ).thenAnswer((_) async => usuario);
    when(
      () => mockPublicacionRepository.buscarDisponibles(
        etapaEdad: any(named: 'etapaEdad'),
        categoria: any(named: 'categoria'),
        colegio: any(named: 'colegio'),
        barrio: any(named: 'barrio'),
        talle: any(named: 'talle'),
        colores: any(named: 'colores'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockPublicacionRepository.listarPorVendedor('uid-1'),
    ).thenAnswer((_) async => []);
    when(
      () => mockFavoritoRepository.idsFavoritos('uid-1'),
    ).thenAnswer((_) => Stream.value(const []));
    when(
      () => mockUserProfileRepository.obtenerPorId('uid-1'),
    ).thenAnswer((_) async => null);
    when(
      () => mockMercadoPagoRepository.estaConectada('uid-1'),
    ).thenAnswer((_) async => false);
    when(
      () => mockChatRepository.misConversaciones('uid-1'),
    ).thenAnswer((_) => Stream.value(const []));
    when(
      () => mockFcmTokenService.obtenerEstadoPermiso(),
    ).thenAnswer((_) async => AuthorizationStatus.authorized);
  });

  Future<void> pumpPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          publicacionRepositoryProvider.overrideWithValue(
            mockPublicacionRepository,
          ),
          favoritoRepositoryProvider.overrideWithValue(mockFavoritoRepository),
          userProfileRepositoryProvider.overrideWithValue(
            mockUserProfileRepository,
          ),
          mercadoPagoRepositoryProvider.overrideWithValue(
            mockMercadoPagoRepository,
          ),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
          fcmTokenServiceProvider.overrideWithValue(mockFcmTokenService),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Las 4 pestañas comparten un IndexedStack, que construye (pero no pinta)
  // a todas por igual — `find.text` encuentra widgets aunque no estén
  // pintados, así que la pestaña activa se verifica por el índice
  // seleccionado de la barra, no por qué texto aparece en pantalla.
  int indiceSeleccionado(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('arranca en la pestaña Inicio (índice 0)', (tester) async {
    await pumpPantalla(tester);

    expect(indiceSeleccionado(tester), 0);
  });

  testWidgets('tocar "Mis ventas" selecciona el índice 1', (tester) async {
    await pumpPantalla(tester);

    await tester.tap(find.text('Mis ventas'));
    await tester.pumpAndSettle();

    expect(indiceSeleccionado(tester), 1);
  });

  testWidgets('tocar "Perfil" selecciona el índice 3', (tester) async {
    await pumpPantalla(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(indiceSeleccionado(tester), 3);
  });

  testWidgets(
    'desde "Mis ventas", tocar un paso del onboarding va a la pestaña Perfil',
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

      await pumpPantalla(tester);
      await tester.tap(find.text('Mis ventas'));
      await tester.pumpAndSettle();
      expect(indiceSeleccionado(tester), 1);

      await tester.tap(
        find.text('Verificá tu identidad para compras protegidas'),
      );
      await tester.pumpAndSettle();

      expect(indiceSeleccionado(tester), 3);
    },
  );
}
