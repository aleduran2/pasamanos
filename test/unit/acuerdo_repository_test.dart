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
    expect(mensajes, hasLength(1));
    expect(mensajes.first.tipo, TipoMensaje.sistema);
    expect(mensajes.first.texto, contains('4500'));
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
}
