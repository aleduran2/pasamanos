import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/acuerdos/data/acuerdo_repository.dart';
import 'package:pasamanos/features/acuerdos/models/acuerdo.dart';
import 'package:pasamanos/features/acuerdos/providers/acuerdo_providers.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';
import 'package:pasamanos/features/catalogo/data/publicacion_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';
import 'package:pasamanos/features/catalogo/providers/catalogo_providers.dart';
import 'package:pasamanos/features/chat/data/chat_repository.dart';
import 'package:pasamanos/features/chat/models/conversacion.dart';
import 'package:pasamanos/features/chat/models/mensaje.dart';
import 'package:pasamanos/features/chat/presentation/chat_screen.dart';
import 'package:pasamanos/features/chat/providers/chat_providers.dart';
import 'package:pasamanos/features/perfil/data/user_profile_repository.dart';
import 'package:pasamanos/features/perfil/providers/perfil_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockPublicacionRepository extends Mock implements PublicacionRepository {}

class _MockAcuerdoRepository extends Mock implements AcuerdoRepository {}

class _MockUserProfileRepository extends Mock implements UserProfileRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;
  late _MockChatRepository mockChatRepository;
  late _MockPublicacionRepository mockPublicacionRepository;
  late _MockAcuerdoRepository mockAcuerdoRepository;
  late _MockUserProfileRepository mockUserProfileRepository;

  const usuarioCompradora = AppUser(
    uid: 'uid-compradora',
    email: 'compradora@example.com',
  );
  const conversacion = Conversacion(
    id: 'pub-1_uid-compradora',
    publicacionId: 'pub-1',
    publicacionTitulo: 'Guardapolvo talle 8',
    compradorId: 'uid-compradora',
    vendedorId: 'uid-vendedora',
  );
  const publicacion = Publicacion(
    id: 'pub-1',
    vendedorId: 'uid-vendedora',
    titulo: 'Guardapolvo talle 8',
    descripcion: 'Usado',
    categoria: Categoria.uniformes,
    etapaEdad: EtapaEdad.primaria,
    precio: 5000,
    fotos: FotosPublicacion(
      frente: 'a',
      dorso: 'b',
      etiqueta: 'c',
      detalle: 'd',
    ),
  );

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
    mockChatRepository = _MockChatRepository();
    mockPublicacionRepository = _MockPublicacionRepository();
    mockAcuerdoRepository = _MockAcuerdoRepository();
    mockUserProfileRepository = _MockUserProfileRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(usuarioCompradora);
    when(
      () => mockChatRepository.mensajes('pub-1_uid-compradora'),
    ).thenAnswer((_) => Stream.value(const []));
    when(
      () => mockPublicacionRepository.obtenerPorId('pub-1'),
    ).thenAnswer((_) async => publicacion);
    when(
      () => mockChatRepository.marcarComoLeido(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockAcuerdoRepository.obtenerPorConversacion(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockAcuerdoRepository.observarPorConversacion(
        any(),
        miUid: any(named: 'miUid'),
      ),
    ).thenAnswer((_) => Stream.value(null));
    when(
      () => mockUserProfileRepository.obtenerPorId(any()),
    ).thenAnswer((_) async => null);
  });

  Future<void> pumpPantalla(WidgetTester tester) async {
    // Tamaño chico por defecto en test (800x600) — con varios banners
    // apilados (stepper + elegir camino/pago/whatsapp/etc.) no entra ni el
    // estado vacío de los mensajes. Se agranda a algo parecido a un
    // teléfono real, donde esto nunca pasa.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
          publicacionRepositoryProvider.overrideWithValue(
            mockPublicacionRepository,
          ),
          acuerdoRepositoryProvider.overrideWithValue(mockAcuerdoRepository),
          userProfileRepositoryProvider.overrideWithValue(
            mockUserProfileRepository,
          ),
        ],
        child: const MaterialApp(home: ChatScreen(conversacion: conversacion)),
      ),
    );
  }

  testWidgets('muestra los mensajes de la conversación', (tester) async {
    when(() => mockChatRepository.mensajes('pub-1_uid-compradora')).thenAnswer(
      (_) => Stream.value(const [
        Mensaje(id: 'm1', emisorId: 'uid-vendedora', texto: 'Hola, sí está'),
      ]),
    );

    await pumpPantalla(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Hola, sí está'), findsOneWidget);
  });

  testWidgets('enviar un mensaje llama al repositorio y limpia el campo', (
    tester,
  ) async {
    when(
      () => mockChatRepository.enviarMensaje(
        conversacionId: any(named: 'conversacionId'),
        emisorId: any(named: 'emisorId'),
        texto: any(named: 'texto'),
      ),
    ).thenAnswer((_) async {});

    await pumpPantalla(tester);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hola, ¿sigue disponible?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    verify(
      () => mockChatRepository.enviarMensaje(
        conversacionId: 'pub-1_uid-compradora',
        emisorId: 'uid-compradora',
        texto: 'Hola, ¿sigue disponible?',
      ),
    ).called(1);
    expect(
      find.widgetWithText(TextField, 'Hola, ¿sigue disponible?'),
      findsNothing,
    );
  });

  testWidgets('no muestra "Cerrar acuerdo" si soy la compradora', (
    tester,
  ) async {
    await pumpPantalla(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Cerrar acuerdo'), findsNothing);
  });

  testWidgets('muestra "Cerrar acuerdo" si soy la vendedora y está disponible', (
    tester,
  ) async {
    when(() => mockAuthRepository.currentUser).thenReturn(
      const AppUser(uid: 'uid-vendedora', email: 'vendedora@example.com'),
    );

    await pumpPantalla(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Cerrar acuerdo'), findsOneWidget);
  });

  const acuerdoSinElegir = Acuerdo(
    id: 'acuerdo-1',
    conversacionId: 'pub-1_uid-compradora',
    publicacionId: 'pub-1',
    compradorId: 'uid-compradora',
    vendedorId: 'uid-vendedora',
    precioAcordado: 5000,
  );

  testWidgets(
    'compradora ve las dos opciones cuando el trato está activo y sin elegir camino',
    (tester) async {
      when(
        () => mockAcuerdoRepository.observarPorConversacion(
          any(),
          miUid: 'uid-compradora',
        ),
      ).thenAnswer((_) => Stream.value(acuerdoSinElegir));

      await pumpPantalla(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('Pagar con Mercado Pago'), findsOneWidget);
      expect(find.text('Coordinar por WhatsApp'), findsOneWidget);
    },
  );

  testWidgets(
    'trato directo habilita WhatsApp sin pedir verificación aunque el monto sea alto',
    (tester) async {
      final acuerdoDirecto = Acuerdo(
        id: 'acuerdo-1',
        conversacionId: 'pub-1_uid-compradora',
        publicacionId: 'pub-1',
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
        precioAcordado: 25000, // supera el monto mínimo de KYC ($20.000)
        coordinacionDirecta: true,
      );
      when(
        () => mockAcuerdoRepository.observarPorConversacion(
          any(),
          miUid: 'uid-compradora',
        ),
      ).thenAnswer((_) => Stream.value(acuerdoDirecto));

      await pumpPantalla(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('Compartir mi WhatsApp'), findsOneWidget);
      expect(find.text('Verificar identidad'), findsNothing);
      expect(find.text('Pagar con Mercado Pago'), findsNothing);
    },
  );

  testWidgets(
    'compra protegida exige verificación antes de habilitar WhatsApp si el monto es alto',
    (tester) async {
      final acuerdoCaroPagado = Acuerdo(
        id: 'acuerdo-1',
        conversacionId: 'pub-1_uid-compradora',
        publicacionId: 'pub-1',
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
        precioAcordado: 25000,
        estadoPago: 'approved',
      );
      when(
        () => mockAcuerdoRepository.observarPorConversacion(
          any(),
          miUid: 'uid-compradora',
        ),
      ).thenAnswer((_) => Stream.value(acuerdoCaroPagado));

      await pumpPantalla(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('Verificar identidad'), findsOneWidget);
      expect(find.text('Compartir mi WhatsApp'), findsNothing);
    },
  );

  testWidgets(
    'vendedora ve el banner de espera mientras la compradora no eligió camino',
    (tester) async {
      when(() => mockAuthRepository.currentUser).thenReturn(
        const AppUser(uid: 'uid-vendedora', email: 'vendedora@example.com'),
      );
      when(
        () => mockAcuerdoRepository.observarPorConversacion(
          any(),
          miUid: 'uid-vendedora',
        ),
      ).thenAnswer((_) => Stream.value(acuerdoSinElegir));

      await pumpPantalla(tester);
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Esperando que la compradora elija'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'vendedora puede marcar como vendido con trato directo, sin pago',
    (tester) async {
      const publicacionReservada = Publicacion(
        id: 'pub-1',
        vendedorId: 'uid-vendedora',
        titulo: 'Guardapolvo talle 8',
        descripcion: 'Usado',
        categoria: Categoria.uniformes,
        etapaEdad: EtapaEdad.primaria,
        precio: 5000,
        fotos: FotosPublicacion(
          frente: 'a',
          dorso: 'b',
          etiqueta: 'c',
          detalle: 'd',
        ),
        estado: EstadoPublicacion.reservado,
      );
      when(
        () => mockPublicacionRepository.obtenerPorId('pub-1'),
      ).thenAnswer((_) async => publicacionReservada);
      when(() => mockAuthRepository.currentUser).thenReturn(
        const AppUser(uid: 'uid-vendedora', email: 'vendedora@example.com'),
      );
      final acuerdoDirecto = Acuerdo(
        id: 'acuerdo-1',
        conversacionId: 'pub-1_uid-compradora',
        publicacionId: 'pub-1',
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
        precioAcordado: 5000,
        coordinacionDirecta: true,
      );
      when(
        () => mockAcuerdoRepository.observarPorConversacion(
          any(),
          miUid: 'uid-vendedora',
        ),
      ).thenAnswer((_) => Stream.value(acuerdoDirecto));

      await pumpPantalla(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('Marcar como vendido'), findsOneWidget);
      expect(find.textContaining('Pago confirmado'), findsNothing);
    },
  );
}
