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
import 'package:pasamanos/features/chat/models/conversacion.dart';
import 'package:pasamanos/features/chat/models/mensaje.dart';
import 'package:pasamanos/features/chat/presentation/chat_screen.dart';
import 'package:pasamanos/features/chat/providers/chat_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockPublicacionRepository extends Mock implements PublicacionRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;
  late _MockChatRepository mockChatRepository;
  late _MockPublicacionRepository mockPublicacionRepository;

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
    when(() => mockAuthRepository.currentUser).thenReturn(usuarioCompradora);
    when(
      () => mockChatRepository.mensajes('pub-1_uid-compradora'),
    ).thenAnswer((_) => Stream.value(const []));
    when(
      () => mockPublicacionRepository.obtenerPorId('pub-1'),
    ).thenAnswer((_) async => publicacion);
  });

  Future<void> pumpPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
          publicacionRepositoryProvider.overrideWithValue(
            mockPublicacionRepository,
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
    await tester.tap(find.byIcon(Icons.send));
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
}
