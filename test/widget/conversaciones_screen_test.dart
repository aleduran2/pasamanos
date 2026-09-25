import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pasamanos/features/acuerdos/data/acuerdo_repository.dart';
import 'package:pasamanos/features/acuerdos/providers/acuerdo_providers.dart';
import 'package:pasamanos/features/auth/data/auth_repository.dart';
import 'package:pasamanos/features/auth/models/app_user.dart';
import 'package:pasamanos/features/auth/providers/auth_providers.dart';
import 'package:pasamanos/features/chat/data/chat_repository.dart';
import 'package:pasamanos/features/chat/models/conversacion.dart';
import 'package:pasamanos/features/chat/presentation/conversaciones_screen.dart';
import 'package:pasamanos/features/chat/providers/chat_providers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockAcuerdoRepository extends Mock implements AcuerdoRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;
  late _MockChatRepository mockChatRepository;
  late _MockAcuerdoRepository mockAcuerdoRepository;

  const usuario = AppUser(uid: 'uid-compradora', email: 'compradora@example.com');

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
    mockChatRepository = _MockChatRepository();
    mockAcuerdoRepository = _MockAcuerdoRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(usuario);
    when(
      () => mockAcuerdoRepository.observarPorConversacion(
        any(),
        miUid: any(named: 'miUid'),
      ),
    ).thenAnswer((_) => Stream.value(null));
  });

  Future<void> pumpPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
          acuerdoRepositoryProvider.overrideWithValue(mockAcuerdoRepository),
        ],
        child: const MaterialApp(home: ConversacionesScreen()),
      ),
    );
  }

  testWidgets('muestra estado vacío sin conversaciones', (tester) async {
    when(
      () => mockChatRepository.misConversaciones('uid-compradora'),
    ).thenAnswer((_) => Stream.value(const []));

    await pumpPantalla(tester);
    await tester.pump();

    expect(
      find.textContaining('Todavía no tenés conversaciones'),
      findsOneWidget,
    );
  });

  testWidgets('muestra la lista de conversaciones', (tester) async {
    when(() => mockChatRepository.misConversaciones('uid-compradora')).thenAnswer(
      (_) => Stream.value([
        const Conversacion(
          id: 'pub-1_uid-compradora',
          publicacionId: 'pub-1',
          publicacionTitulo: 'Guardapolvo talle 8',
          compradorId: 'uid-compradora',
          vendedorId: 'uid-vendedora',
          ultimoMensaje: 'Hola, ¿sigue disponible?',
        ),
      ]),
    );

    await pumpPantalla(tester);
    await tester.pump();

    expect(find.text('Guardapolvo talle 8'), findsOneWidget);
    expect(find.text('Hola, ¿sigue disponible?'), findsOneWidget);
  });
}
