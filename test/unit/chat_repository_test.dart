import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/features/chat/data/chat_repository.dart';
import 'package:pasamanos/features/chat/models/conversacion.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreChatRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreChatRepository(firestore: firestore);
  });

  test('obtenerOCrear crea la conversación con ID determinístico', () async {
    final conversacion = await repository.obtenerOCrear(
      publicacionId: 'pub-1',
      publicacionTitulo: 'Guardapolvo talle 8',
      compradorId: 'uid-compradora',
      vendedorId: 'uid-vendedora',
    );

    expect(conversacion.id, 'pub-1_uid-compradora');
    expect(conversacion.estado, EstadoConversacion.activa);

    final doc = await firestore
        .collection('conversaciones')
        .doc('pub-1_uid-compradora')
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['participantes'], ['uid-compradora', 'uid-vendedora']);
  });

  test('obtenerOCrear no duplica si ya existe', () async {
    await repository.obtenerOCrear(
      publicacionId: 'pub-1',
      publicacionTitulo: 'Guardapolvo talle 8',
      compradorId: 'uid-compradora',
      vendedorId: 'uid-vendedora',
    );

    await repository.enviarMensaje(
      conversacionId: 'pub-1_uid-compradora',
      emisorId: 'uid-compradora',
      texto: 'Hola, ¿todavía está disponible?',
    );

    final conversacion = await repository.obtenerOCrear(
      publicacionId: 'pub-1',
      publicacionTitulo: 'Guardapolvo talle 8',
      compradorId: 'uid-compradora',
      vendedorId: 'uid-vendedora',
    );

    expect(conversacion.ultimoMensaje, 'Hola, ¿todavía está disponible?');
  });

  test('misConversaciones devuelve solo las del usuario', () async {
    await repository.obtenerOCrear(
      publicacionId: 'pub-1',
      publicacionTitulo: 'Producto 1',
      compradorId: 'uid-compradora',
      vendedorId: 'uid-vendedora',
    );
    await repository.obtenerOCrear(
      publicacionId: 'pub-2',
      publicacionTitulo: 'Producto 2',
      compradorId: 'otra-uid',
      vendedorId: 'uid-vendedora-2',
    );

    final conversaciones = await repository
        .misConversaciones('uid-compradora')
        .first;

    expect(conversaciones, hasLength(1));
    expect(conversaciones.first.publicacionId, 'pub-1');
  });

  test('enviarMensaje agrega el mensaje y actualiza el resumen', () async {
    await repository.obtenerOCrear(
      publicacionId: 'pub-1',
      publicacionTitulo: 'Producto 1',
      compradorId: 'uid-compradora',
      vendedorId: 'uid-vendedora',
    );

    await repository.enviarMensaje(
      conversacionId: 'pub-1_uid-compradora',
      emisorId: 'uid-compradora',
      texto: 'Hola',
    );
    await repository.enviarMensaje(
      conversacionId: 'pub-1_uid-compradora',
      emisorId: 'uid-vendedora',
      texto: 'Hola, sí, está disponible',
    );

    final mensajes = await repository
        .mensajes('pub-1_uid-compradora')
        .first;

    expect(mensajes, hasLength(2));
    expect(mensajes.first.texto, 'Hola');
    expect(mensajes.last.texto, 'Hola, sí, está disponible');

    final doc = await firestore
        .collection('conversaciones')
        .doc('pub-1_uid-compradora')
        .get();
    expect(doc.data()!['ultimoMensaje'], 'Hola, sí, está disponible');
  });
}
