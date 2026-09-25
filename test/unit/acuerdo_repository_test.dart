import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/features/acuerdos/data/acuerdo_repository.dart';
import 'package:pasamanos/features/acuerdos/models/acuerdo.dart';
import 'package:pasamanos/features/catalogo/data/publicacion_repository.dart';
import 'package:pasamanos/features/catalogo/models/publicacion.dart';
import 'package:pasamanos/features/chat/data/chat_repository.dart';
import 'package:pasamanos/features/chat/models/mensaje.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreAcuerdoRepository acuerdoRepository;
  late FirestorePublicacionRepository publicacionRepository;
  late FirestoreChatRepository chatRepository;

  const fotos = FotosPublicacion(
    frente: 'a',
    dorso: 'b',
    etiqueta: 'c',
    detalle: 'd',
  );

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    acuerdoRepository = FirestoreAcuerdoRepository(firestore: firestore);
    publicacionRepository = FirestorePublicacionRepository(
      firestore: firestore,
    );
    chatRepository = FirestoreChatRepository(firestore: firestore);
  });

  Future<String> crearPublicacionDisponible() async {
    final id = publicacionRepository.generarId();
    await publicacionRepository.guardar(
      Publicacion(
        id: id,
        vendedorId: 'uid-vendedora',
        titulo: 'Guardapolvo talle 8',
        descripcion: 'Usado',
        categoria: Categoria.uniformes,
        etapaEdad: EtapaEdad.primaria,
        precio: 5000,
        fotos: fotos,
      ),
    );
    return id;
  }

  test('cerrarAcuerdo crea el acuerdo y reserva la publicación', () async {
    final publicacionId = await crearPublicacionDisponible();
    await chatRepository.obtenerOCrear(
      publicacionId: publicacionId,
      publicacionTitulo: 'Guardapolvo talle 8',
      compradorId: 'uid-compradora',
      vendedorId: 'uid-vendedora',
    );
    final conversacionId = '${publicacionId}_uid-compradora';

    final acuerdo = await acuerdoRepository.cerrarAcuerdo(
      conversacionId: conversacionId,
      publicacionId: publicacionId,
      compradorId: 'uid-compradora',
      vendedorId: 'uid-vendedora',
      precioAcordado: 4500,
    );

    expect(acuerdo.precioAcordado, 4500);
    expect(acuerdo.estado, EstadoAcuerdo.activo);

    final publicacion = await publicacionRepository.obtenerPorId(
      publicacionId,
    );
    expect(publicacion!.estado, EstadoPublicacion.reservado);

    final mensajes = await chatRepository.mensajes(conversacionId).first;
    expect(mensajes, hasLength(2));
    expect(mensajes.last.tipo, TipoMensaje.sistema);
    expect(mensajes.last.texto, contains('4.500'));
  });

  test(
    'cerrarAcuerdo lanza PublicacionNoDisponibleException si ya no está disponible',
    () async {
      final publicacionId = await crearPublicacionDisponible();
      await chatRepository.obtenerOCrear(
        publicacionId: publicacionId,
        publicacionTitulo: 'Guardapolvo talle 8',
        compradorId: 'uid-compradora-1',
        vendedorId: 'uid-vendedora',
      );
      await acuerdoRepository.cerrarAcuerdo(
        conversacionId: '${publicacionId}_uid-compradora-1',
        publicacionId: publicacionId,
        compradorId: 'uid-compradora-1',
        vendedorId: 'uid-vendedora',
        precioAcordado: 5000,
      );

      // Otro comprador intenta cerrar el mismo trato después.
      await chatRepository.obtenerOCrear(
        publicacionId: publicacionId,
        publicacionTitulo: 'Guardapolvo talle 8',
        compradorId: 'uid-compradora-2',
        vendedorId: 'uid-vendedora',
      );

      expect(
        () => acuerdoRepository.cerrarAcuerdo(
          conversacionId: '${publicacionId}_uid-compradora-2',
          publicacionId: publicacionId,
          compradorId: 'uid-compradora-2',
          vendedorId: 'uid-vendedora',
          precioAcordado: 5000,
        ),
        throwsA(isA<PublicacionNoDisponibleException>()),
      );
    },
  );

  test('obtenerPorConversacion devuelve null si no hay acuerdo', () async {
    final acuerdo = await acuerdoRepository.obtenerPorConversacion(
      'no-existe',
    );
    expect(acuerdo, isNull);
  });

  test(
    'marcarVendido pasa la publicación a vendido y el acuerdo a completado',
    () async {
      final publicacionId = await crearPublicacionDisponible();
      await chatRepository.obtenerOCrear(
        publicacionId: publicacionId,
        publicacionTitulo: 'Guardapolvo talle 8',
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
      );
      final conversacionId = '${publicacionId}_uid-compradora';
      await acuerdoRepository.cerrarAcuerdo(
        conversacionId: conversacionId,
        publicacionId: publicacionId,
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
        precioAcordado: 4500,
      );

      await acuerdoRepository.marcarVendido(
        publicacionId,
        miUid: 'uid-vendedora',
      );

      final publicacion = await publicacionRepository.obtenerPorId(
        publicacionId,
      );
      expect(publicacion!.estado, EstadoPublicacion.vendido);

      final acuerdo = await acuerdoRepository.obtenerPorConversacion(
        conversacionId,
      );
      expect(acuerdo!.estado, EstadoAcuerdo.completado);

      final mensajes = await chatRepository.mensajes(conversacionId).first;
      expect(mensajes, hasLength(3));
      expect(mensajes.last.tipo, TipoMensaje.sistema);
    },
  );

  test(
    'cancelarReserva devuelve la publicación a disponible y cancela el acuerdo',
    () async {
      final publicacionId = await crearPublicacionDisponible();
      await chatRepository.obtenerOCrear(
        publicacionId: publicacionId,
        publicacionTitulo: 'Guardapolvo talle 8',
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
      );
      final conversacionId = '${publicacionId}_uid-compradora';
      await acuerdoRepository.cerrarAcuerdo(
        conversacionId: conversacionId,
        publicacionId: publicacionId,
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
        precioAcordado: 4500,
      );

      await acuerdoRepository.cancelarReserva(
        publicacionId,
        miUid: 'uid-vendedora',
      );

      final publicacion = await publicacionRepository.obtenerPorId(
        publicacionId,
      );
      expect(publicacion!.estado, EstadoPublicacion.disponible);

      final acuerdo = await acuerdoRepository.obtenerPorConversacion(
        conversacionId,
      );
      expect(acuerdo!.estado, EstadoAcuerdo.cancelado);
    },
  );

  test(
    'compartirTelefono guarda el número en el campo propio y avisa en el chat',
    () async {
      final publicacionId = await crearPublicacionDisponible();
      await chatRepository.obtenerOCrear(
        publicacionId: publicacionId,
        publicacionTitulo: 'Guardapolvo talle 8',
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
      );
      final conversacionId = '${publicacionId}_uid-compradora';
      final acuerdo = await acuerdoRepository.cerrarAcuerdo(
        conversacionId: conversacionId,
        publicacionId: publicacionId,
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
        precioAcordado: 4500,
      );

      await acuerdoRepository.compartirTelefono(
        acuerdoId: acuerdo.id,
        conversacionId: conversacionId,
        esComprador: true,
        emisorId: 'uid-compradora',
        telefono: '2211234567',
      );

      final acuerdoActualizado = await acuerdoRepository.obtenerPorConversacion(
        conversacionId,
      );
      expect(acuerdoActualizado!.telefonoComprador, '2211234567');
      expect(acuerdoActualizado.telefonoVendedor, isNull);

      final mensajes = await chatRepository.mensajes(conversacionId).first;
      expect(mensajes, hasLength(3));
      expect(mensajes.last.emisorId, 'uid-compradora');
      expect(mensajes.last.tipo, TipoMensaje.sistema);
    },
  );

  test(
    'elegirTratoDirecto marca el acuerdo y avisa en el chat',
    () async {
      final publicacionId = await crearPublicacionDisponible();
      await chatRepository.obtenerOCrear(
        publicacionId: publicacionId,
        publicacionTitulo: 'Guardapolvo talle 8',
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
      );
      final conversacionId = '${publicacionId}_uid-compradora';
      final acuerdo = await acuerdoRepository.cerrarAcuerdo(
        conversacionId: conversacionId,
        publicacionId: publicacionId,
        compradorId: 'uid-compradora',
        vendedorId: 'uid-vendedora',
        precioAcordado: 25000,
      );
      expect(acuerdo.coordinacionDirecta, isFalse);

      await acuerdoRepository.elegirTratoDirecto(
        acuerdoId: acuerdo.id,
        conversacionId: conversacionId,
        compradorId: 'uid-compradora',
      );

      final acuerdoActualizado = await acuerdoRepository.obtenerPorConversacion(
        conversacionId,
      );
      expect(acuerdoActualizado!.coordinacionDirecta, isTrue);

      final mensajes = await chatRepository.mensajes(conversacionId).first;
      expect(mensajes.last.tipo, TipoMensaje.sistema);
      expect(mensajes.last.texto, contains('coordinar directo'));
    },
  );
}
