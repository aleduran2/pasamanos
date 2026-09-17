import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';
import 'package:pasamanos/features/chat/data/chat_repository.dart';
import 'package:pasamanos/features/chat/models/conversacion.dart';
import 'package:pasamanos/features/chat/models/mensaje.dart';
import 'package:pasamanos/features/chat/presentation/chat_screen.dart';
import 'package:pasamanos/features/chat/providers/chat_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;
  late _MockChatRepository mockChatRepository;

  const usuario = AppUser(uid: 'uid-compradora', email: 'compradora@example.com');
  const conversacion = Conversacion(
    id: 'pub-1_uid-compradora',
    publicacionId: 'pub-1',
    publicacionTitulo: 'Guardapolvo talle 8',
    compradorId: 'uid-compradora',
    vendedorId: 'uid-vendedora',
  );

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
    mockChatRepository = _MockChatRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(usuario);
    when(
      () => mockChatRepository.mensajes('pub-1_uid-compradora'),
    ).thenAnswer((_) => Stream.value(const []));
  });

  Future<void> pumpPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
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
    expect(find.widgetWithText(TextField, 'Hola, ¿sigue disponible?'), findsNothing);
  });
}
