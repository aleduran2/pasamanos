import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formato.dart';
import '../../../core/utils/kyc.dart';
import '../../../core/utils/telefono.dart';
import '../../../core/widgets/dialogo_botones.dart';
import '../../../core/widgets/empty_state.dart';
import '../../acuerdos/data/acuerdo_repository.dart';
import '../../acuerdos/models/acuerdo.dart';
import '../../acuerdos/providers/acuerdo_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calificaciones/providers/calificacion_providers.dart';
import '../../catalogo/models/publicacion.dart';
import '../../catalogo/presentation/publicacion_detail_screen.dart';
import '../../catalogo/providers/catalogo_providers.dart';
import '../../perfil/models/user_profile.dart';
import '../../perfil/presentation/perfil_screen.dart';
import '../../perfil/providers/perfil_providers.dart';
import '../data/chat_repository.dart';
import '../models/conversacion.dart';
import '../models/mensaje.dart';
import '../providers/chat_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversacion});

  final Conversacion conversacion;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _mensajeController = TextEditingController();

  Publicacion? _publicacion;
  Acuerdo? _acuerdoActivo;
  EstadoVerificacion _miEstadoVerificacion = EstadoVerificacion.noVerificado;
  bool _cerrandoAcuerdo = false;
  bool _cambiandoEstado = false;
  bool _pagando = false;
  bool _eligiendoTratoDirecto = false;
  bool _compartiendoTelefono = false;
  bool _yaCalifique = false;
  bool _enviandoCalificacion = false;

  // Se leen una sola vez y se guardan acá: en dispose() ya no es seguro
  // usar `ref` (Riverpod tira un StateError si el widget se está
  // desmontando), así que no se puede volver a leer el provider ahí.
  late final ChatRepository _chatRepository;
  late final AcuerdoRepository _acuerdoRepository;
  String? _miUid;
  StreamSubscription<Acuerdo?>? _acuerdoSub;

  @override
  void initState() {
    super.initState();
    _chatRepository = ref.read(chatRepositoryProvider);
    _acuerdoRepository = ref.read(acuerdoRepositoryProvider);
    _miUid = ref.read(authRepositoryProvider).currentUser?.uid;
    _cargarPublicacion();
    _observarAcuerdo();
    _cargarEstadoVerificacion();
    _marcarComoLeido();
  }

  Future<void> _cargarEstadoVerificacion() async {
    final uid = _miUid;
    if (uid == null) return;
    try {
      final perfil = await ref.read(userProfileRepositoryProvider).obtenerPorId(uid);
      if (mounted && perfil != null) {
        setState(() => _miEstadoVerificacion = perfil.estadoVerificacion);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ChatScreen._cargarEstadoVerificacion error: $error\n$stackTrace',
        );
      }
    }
  }

  Future<void> _cargarPublicacion() async {
    try {
      final publicacion = await ref
          .read(publicacionRepositoryProvider)
          .obtenerPorId(widget.conversacion.publicacionId);
      if (mounted) setState(() => _publicacion = publicacion);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ChatScreen._cargarPublicacion error: $error\n$stackTrace');
      }
    }
  }

  void _observarAcuerdo() {
    final uid = _miUid;
    if (uid == null) return;
    _acuerdoSub = _acuerdoRepository
        .observarPorConversacion(widget.conversacion.id, miUid: uid)
        .listen(
          (acuerdo) {
            if (!mounted) return;
            setState(() => _acuerdoActivo = acuerdo);
            if (acuerdo != null && acuerdo.estado == EstadoAcuerdo.completado) {
              _verificarCalificacion(acuerdo);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode) {
              debugPrint('ChatScreen._observarAcuerdo error: $error\n$stackTrace');
            }
          },
        );
  }

  Future<void> _verificarCalificacion(Acuerdo acuerdo) async {
    final uid = _miUid;
    if (uid == null) return;
    try {
      final ya = await ref
          .read(calificacionRepositoryProvider)
          .yaCalifique(acuerdoId: acuerdo.id, autorId: uid);
      if (mounted) setState(() => _yaCalifique = ya);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ChatScreen._verificarCalificacion error: $error\n$stackTrace',
        );
      }
    }
  }

  Future<void> _compartirWhatsapp() async {
    final acuerdo = _acuerdoActivo;
    final uid = _miUid;
    if (acuerdo == null || uid == null) return;
    final esComprador = acuerdo.compradorId == uid;

    final telefonoController = TextEditingController(
      text: esComprador ? acuerdo.telefonoComprador : acuerdo.telefonoVendedor,
    );
    String? error;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Compartir WhatsApp'),
          content: TextField(
            controller: telefonoController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ej: 2211234567',
              errorText: error,
            ),
            onChanged: (_) {
              if (error != null) setDialogState(() => error = null);
            },
          ),
          actions: [
            DialogoBotones(
              textoCancelar: 'Cancelar',
              textoConfirmar: 'Compartir',
              onCancelar: () => Navigator.of(context).pop(false),
              onConfirmar: () {
                final texto = telefonoController.text.trim();
                if (!esTelefonoValido(texto)) {
                  setDialogState(() => error = mensajeTelefonoInvalido);
                  return;
                }
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );
    if (confirmado != true) return;
    final telefono = telefonoController.text.trim();

    setState(() => _compartiendoTelefono = true);
    try {
      await ref
          .read(acuerdoRepositoryProvider)
          .compartirTelefono(
            acuerdoId: acuerdo.id,
            conversacionId: widget.conversacion.id,
            esComprador: esComprador,
            emisorId: uid,
            telefono: telefono,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir el WhatsApp.')),
        );
      }
    } finally {
      if (mounted) setState(() => _compartiendoTelefono = false);
    }
  }

  Future<void> _abrirWhatsapp(String telefono) async {
    final numero = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final abierto = await launchUrl(
      Uri.parse('https://wa.me/$numero'),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  Future<void> _abrirDialogoCalificar() async {
    final acuerdo = _acuerdoActivo;
    final uid = _miUid;
    if (acuerdo == null || uid == null) return;
    final destinatarioId = acuerdo.compradorId == uid
        ? acuerdo.vendedorId
        : acuerdo.compradorId;

    var puntaje = 5;
    final comentarioController = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calificar a la otra persona'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (indice) {
                  final valor = indice + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => puntaje = valor),
                    icon: Icon(
                      valor <= puntaje
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              TextField(
                controller: comentarioController,
                decoration: const InputDecoration(
                  hintText: 'Comentario (opcional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            DialogoBotones(
              textoCancelar: 'Cancelar',
              textoConfirmar: 'Enviar',
              onCancelar: () => Navigator.of(context).pop(false),
              onConfirmar: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmado != true) return;

    setState(() => _enviandoCalificacion = true);
    try {
      final comentario = comentarioController.text.trim();
      await ref
          .read(calificacionRepositoryProvider)
          .crear(
            acuerdoId: acuerdo.id,
            autorId: uid,
            destinatarioId: destinatarioId,
            puntaje: puntaje,
            comentario: comentario.isEmpty ? null : comentario,
          );
      if (mounted) setState(() => _yaCalifique = true);
      // Best-effort: si esto falla, la calificación ya quedó guardada de
      // todos modos — solo se pierde el aviso en el chat.
      try {
        await _chatRepository.enviarMensaje(
          conversacionId: widget.conversacion.id,
          emisorId: uid,
          texto:
              'Calificó este trato con $puntaje '
              '${puntaje == 1 ? 'estrella' : 'estrellas'}.',
          tipo: TipoMensaje.sistema,
        );
      } catch (_) {
        // Silencioso a propósito: no queremos que un aviso decorativo
        // haga parecer que la calificación en sí falló.
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la calificación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoCalificacion = false);
    }
  }

  Future<void> _pagar() async {
    final acuerdo = _acuerdoActivo;
    if (acuerdo == null) return;

    setState(() => _pagando = true);
    try {
      final resultado = await FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('crearPreferenciaPago').call<Map<String, dynamic>>({
        'acuerdoId': acuerdo.id,
      });
      final initPoint = resultado.data['initPoint'] as String?;
      if (initPoint == null) throw Exception('Sin link de pago');

      final abierto = await launchUrl(
        Uri.parse(initPoint),
        mode: LaunchMode.externalApplication,
      );
      if (!abierto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Mercado Pago.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'No se pudo generar el pago.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar el pago.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  Future<void> _abrirDialogoTratoDirecto() async {
    final acuerdo = _acuerdoActivo;
    final uid = _miUid;
    if (acuerdo == null || uid == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coordinar directo por WhatsApp'),
        content: const Text(
          'Vas a coordinar la entrega y el pago por tu cuenta, sin pasar '
          'por Mercado Pago. Esto significa: sin verificación de '
          'identidad y sin la protección de Pasamanos sobre este trato. '
          'No se puede deshacer.',
        ),
        actions: [
          DialogoBotones(
            textoCancelar: 'Cancelar',
            textoConfirmar: 'Coordinar directo',
            onCancelar: () => Navigator.of(context).pop(false),
            onConfirmar: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _eligiendoTratoDirecto = true);
    try {
      await _acuerdoRepository.elegirTratoDirecto(
        acuerdoId: acuerdo.id,
        conversacionId: widget.conversacion.id,
        compradorId: uid,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la elección.')),
        );
      }
    } finally {
      if (mounted) setState(() => _eligiendoTratoDirecto = false);
    }
  }

  void _marcarComoLeido() {
    final uid = _miUid;
    if (uid == null) return;
    _chatRepository.marcarComoLeido(widget.conversacion.id, uid);
  }

  @override
  void dispose() {
    // De vuelta al salir, por si llegaron mensajes nuevos mientras la
    // pantalla estaba abierta (el primer marcado, en initState, no los
    // habría cubierto).
    _marcarComoLeido();
    _acuerdoSub?.cancel();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty) return;
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    _mensajeController.clear();
    await ref
        .read(chatRepositoryProvider)
        .enviarMensaje(
          conversacionId: widget.conversacion.id,
          emisorId: usuario.uid,
          texto: texto,
        );
  }

  Future<void> _abrirDialogoCerrarAcuerdo() async {
    final publicacion = _publicacion;
    if (publicacion == null) return;

    final precioController = TextEditingController(
      text: publicacion.precio.toStringAsFixed(0),
    );
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar acuerdo'),
        content: TextField(
          controller: precioController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Precio acordado'),
        ),
        actions: [
          DialogoBotones(
            textoCancelar: 'Cancelar',
            textoConfirmar: 'Confirmar',
            onCancelar: () => Navigator.of(context).pop(false),
            onConfirmar: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final precio = double.tryParse(
      precioController.text.replaceAll(',', '.'),
    );
    if (precio == null || precio <= 0) return;

    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    setState(() => _cerrandoAcuerdo = true);
    try {
      await ref
          .read(acuerdoRepositoryProvider)
          .cerrarAcuerdo(
            conversacionId: widget.conversacion.id,
            publicacionId: publicacion.id,
            compradorId: widget.conversacion.compradorId,
            vendedorId: usuario.uid,
            precioAcordado: precio,
          );
      await _cargarPublicacion();
    } on PublicacionNoDisponibleException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta publicación ya no está disponible.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cerrar el acuerdo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cerrandoAcuerdo = false);
    }
  }

  Future<void> _marcarVendido() async {
    final publicacion = _publicacion;
    final uid = _miUid;
    if (publicacion == null || uid == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como vendido'),
        content: const Text(
          'La publicación va a figurar como vendida y ya no va a poder '
          'reservarse de nuevo.',
        ),
        actions: [
          DialogoBotones(
            textoCancelar: 'Cancelar',
            textoConfirmar: 'Confirmar',
            onCancelar: () => Navigator.of(context).pop(false),
            onConfirmar: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _cambiandoEstado = true);
    try {
      await ref
          .read(acuerdoRepositoryProvider)
          .marcarVendido(publicacion.id, miUid: uid);
      await _cargarPublicacion();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la publicación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cambiandoEstado = false);
    }
  }

  Future<void> _cancelarReserva() async {
    final publicacion = _publicacion;
    final uid = _miUid;
    if (publicacion == null || uid == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text(
          'La publicación vuelve a estar disponible para otras compradoras.',
        ),
        actions: [
          DialogoBotones(
            textoCancelar: 'Volver',
            textoConfirmar: 'Cancelar reserva',
            onCancelar: () => Navigator.of(context).pop(false),
            onConfirmar: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _cambiandoEstado = true);
    try {
      await ref
          .read(acuerdoRepositoryProvider)
          .cancelarReserva(publicacion.id, miUid: uid);
      await _cargarPublicacion();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la publicación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cambiandoEstado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final miUid = ref.read(authRepositoryProvider).currentUser?.uid;
    final ChatRepository chatRepository = ref.read(chatRepositoryProvider);

    final publicacion = _publicacion;
    final puedoOfrecerCierre =
        publicacion != null &&
        publicacion.vendedorId == miUid &&
        publicacion.estado == EstadoPublicacion.disponible;
    final puedoGestionarReserva =
        publicacion != null &&
        publicacion.vendedorId == miUid &&
        publicacion.estado == EstadoPublicacion.reservado;

    final acuerdo = _acuerdoActivo;
    final esComprador = acuerdo != null && acuerdo.compradorId == miUid;
    final coordinacionDirecta = acuerdo?.coordinacionDirecta ?? false;
    // La verificación de identidad es parte de lo que se "paga" al elegir
    // la compra protegida — en trato directo no se pide nunca, sea cual
    // sea el monto (esa fricción de menos es justo lo que hace atractivo
    // el camino gratuito). Tampoco tiene sentido pedirla si el trato ya
    // se canceló — sin este chequeo, el banner se quedaba pegado
    // reclamando verificación para un trato que ya no existe.
    final necesitaVerificacion =
        acuerdo != null &&
        acuerdo.estado != EstadoAcuerdo.cancelado &&
        !coordinacionDirecta &&
        requiereVerificacion(acuerdo.precioAcordado);
    final pagoAprobado = acuerdo != null && acuerdo.estadoPago == 'approved';
    // WhatsApp se habilita por cualquiera de los dos caminos: pago
    // aprobado (compra protegida) o coordinación directa elegida por la
    // compradora (sin pago, sin protección).
    final puedoCompartirWhatsapp =
        acuerdo != null &&
        (acuerdo.estado == EstadoAcuerdo.activo ||
            acuerdo.estado == EstadoAcuerdo.completado) &&
        (coordinacionDirecta ||
            (pagoAprobado &&
                (!necesitaVerificacion ||
                    _miEstadoVerificacion == EstadoVerificacion.verificado)));
    final miTelefono = acuerdo == null
        ? null
        : (esComprador ? acuerdo.telefonoComprador : acuerdo.telefonoVendedor);
    final otroTelefono = acuerdo == null
        ? null
        : (esComprador ? acuerdo.telefonoVendedor : acuerdo.telefonoComprador);
    final whatsappCompleto =
        acuerdo != null &&
        acuerdo.telefonoComprador != null &&
        acuerdo.telefonoVendedor != null;
    // Le falta elegir un camino (ni pagó ni pidió trato directo todavía):
    // ahí es cuando tiene sentido ofrecerle los dos banners de elección.
    final faltaElegirCamino =
        acuerdo != null && !coordinacionDirecta && !pagoAprobado;
    final esperandoPago =
        acuerdo != null &&
        !esComprador &&
        acuerdo.estado == EstadoAcuerdo.activo &&
        faltaElegirCamino;
    final puedoMarcarVendido =
        puedoGestionarReserva && (pagoAprobado || coordinacionDirecta);

    // Sin acuerdo, o con uno cancelado, no hay ningún trato "en curso" que
    // mostrar — mantener el stepper visible después de cancelar daba la
    // falsa impresión de que el trato seguía en pie.
    final pasos = acuerdo == null || acuerdo.estado == EstadoAcuerdo.cancelado
        ? const <_PasoFlujo>[]
        : coordinacionDirecta
        ? <_PasoFlujo>[
            const _PasoFlujo(label: 'Trato cerrado', completado: true),
            const _PasoFlujo(label: 'Trato directo', completado: true),
            _PasoFlujo(label: 'WhatsApp', completado: whatsappCompleto),
            _PasoFlujo(label: 'Calificación', completado: _yaCalifique),
          ]
        : <_PasoFlujo>[
            const _PasoFlujo(label: 'Trato cerrado', completado: true),
            if (necesitaVerificacion)
              _PasoFlujo(
                label: 'Verificación',
                completado: _miEstadoVerificacion == EstadoVerificacion.verificado,
              ),
            _PasoFlujo(label: 'Pago', completado: pagoAprobado),
            _PasoFlujo(label: 'WhatsApp', completado: whatsappCompleto),
            _PasoFlujo(label: 'Calificación', completado: _yaCalifique),
          ];

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: publicacion == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PublicacionDetailScreen(publicacion: publicacion),
                  ),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.conversacion.publicacionTitulo,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (publicacion != null)
                const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
        actions: [
          // "Cerrar acuerdo" vive como banner en el cuerpo del chat (más
          // visible que un botón chico acá) y "Marcar como vendido" tiene
          // su propio banner una vez que el pago está aprobado — acá arriba
          // solo queda la vía de escape para deshacer una reserva.
          if (puedoGestionarReserva)
            IconButton(
              tooltip: 'Cancelar reserva',
              onPressed: _cambiandoEstado ? null : _cancelarReserva,
              icon: const Icon(Icons.undo_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          if (pasos.isNotEmpty) _StepperTrato(pasos: pasos),
          if (puedoOfrecerCierre)
            _BannerCerrarAcuerdo(
              cerrando: _cerrandoAcuerdo,
              onCerrar: _abrirDialogoCerrarAcuerdo,
            ),
          if (necesitaVerificacion &&
              _miEstadoVerificacion != EstadoVerificacion.verificado)
            _BannerDeVerificacion(
              onIrAVerificar: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              ),
            ),
          if (esComprador && faltaElegirCamino && acuerdo.estado == EstadoAcuerdo.activo)
            _BannerElegirCamino(
              acuerdo: acuerdo,
              pagando: _pagando,
              eligiendoDirecto: _eligiendoTratoDirecto,
              onPagar: _pagar,
              onElegirDirecto: _abrirDialogoTratoDirecto,
            ),
          if (esperandoPago) _BannerEsperandoPago(acuerdo: _acuerdoActivo!),
          if (puedoMarcarVendido)
            _BannerMarcarVendido(
              coordinacionDirecta: coordinacionDirecta,
              procesando: _cambiandoEstado,
              onMarcarVendido: _marcarVendido,
            ),
          if (puedoCompartirWhatsapp)
            _BannerWhatsapp(
              miTelefono: miTelefono,
              otroTelefono: otroTelefono,
              compartiendo: _compartiendoTelefono,
              onCompartir: _compartirWhatsapp,
              onAbrir: otroTelefono == null
                  ? null
                  : () => _abrirWhatsapp(otroTelefono),
            ),
          if (acuerdo != null &&
              acuerdo.estado == EstadoAcuerdo.completado &&
              !_yaCalifique)
            _BannerCalificar(
              enviando: _enviandoCalificacion,
              onCalificar: _abrirDialogoCalificar,
            ),
          Expanded(
            child: StreamBuilder<List<Mensaje>>(
              stream: chatRepository.mensajes(widget.conversacion.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline_rounded,
                    mensaje: 'No se pudieron cargar los mensajes.',
                  );
                }
                final mensajes = snapshot.data ?? [];
                if (mensajes.isEmpty) {
                  return const EmptyState(
                    icon: Icons.waving_hand_outlined,
                    mensaje: 'Escribí el primer mensaje.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final mensaje = mensajes[mensajes.length - 1 - index];
                    if (mensaje.tipo == TipoMensaje.sistema) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            mensaje.texto,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      );
                    }
                    final esMio = mensaje.emisorId == miUid;
                    final colorScheme = Theme.of(context).colorScheme;
                    return Align(
                      alignment: esMio
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: esMio
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(esMio ? 18 : 4),
                            bottomRight: Radius.circular(esMio ? 4 : 18),
                          ),
                        ),
                        child: Text(
                          mensaje.texto,
                          style: TextStyle(
                            color: esMio
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribí un mensaje...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _enviar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un paso del recorrido del trato, para [_StepperTrato]. La lista de pasos
/// la arma `_ChatScreenState.build` porque "Verificación" solo corresponde
/// si el monto lo exige — no es siempre la misma cantidad de pasos.
class _PasoFlujo {
  const _PasoFlujo({required this.label, required this.completado});

  final String label;
  final bool completado;
}

/// Indicador fijo arriba del chat con los pasos del trato (cerrado →
/// verificación si hace falta → pago → WhatsApp → calificación) y cuál está
/// activo ahora. Sin esto, cada banner aparece y desaparece por su cuenta
/// sin que ninguna de las dos partes tenga forma de ubicarse en el proceso
/// completo — este widget es la respuesta a esa confusión.
class _StepperTrato extends StatelessWidget {
  const _StepperTrato({required this.pasos});

  final List<_PasoFlujo> pasos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final indiceActual = pasos.indexWhere((paso) => !paso.completado);
    final actual = indiceActual == -1 ? pasos.length - 1 : indiceActual;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < pasos.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: pasos[i].completado || i <= actual
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pasos[i].completado
                        ? colorScheme.primary
                        : (i == actual
                              ? colorScheme.surface
                              : colorScheme.surfaceContainerHighest),
                    border: i == actual && !pasos[i].completado
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: pasos[i].completado
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: colorScheme.onPrimary,
                        )
                      : Text(
                          '${i + 1}',
                          style: textTheme.labelSmall?.copyWith(
                            color: i == actual
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Paso ${actual + 1} de ${pasos.length}: ${pasos[actual].label}',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// CTA para cerrar el trato, dentro del cuerpo del chat en vez de un botón
/// chico en el AppBar — mucho más difícil de pasar por alto para la
/// vendedora, que es quien lo puede usar.
class _BannerCerrarAcuerdo extends StatelessWidget {
  const _BannerCerrarAcuerdo({
    required this.cerrando,
    required this.onCerrar,
  });

  final bool cerrando;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Ya se pusieron de acuerdo en el precio?',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: cerrando ? null : onCerrar,
              icon: cerrando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.handshake_outlined),
              label: const Text('Cerrar acuerdo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Franja para la compradora mientras todavía no eligió un camino: pagar
/// con Mercado Pago (compra protegida, con comisión) o coordinar directo
/// por WhatsApp (gratis, sin protección). Antes esto era obligatorio —
/// ahora es una elección real, con las dos opciones a la vista y sus
/// contrapartidas explicadas, no escondida una atrás de la otra.
class _BannerElegirCamino extends StatelessWidget {
  const _BannerElegirCamino({
    required this.acuerdo,
    required this.pagando,
    required this.eligiendoDirecto,
    required this.onPagar,
    required this.onElegirDirecto,
  });

  final Acuerdo acuerdo;
  final bool pagando;
  final bool eligiendoDirecto;
  final VoidCallback onPagar;
  final VoidCallback onElegirDirecto;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final leyendaPago = switch (acuerdo.estadoPago) {
      'pending' || 'in_process' => 'El pago está en proceso.',
      'rejected' => 'El pago fue rechazado. Podés intentar de nuevo.',
      _ => null,
    };
    final ocupado = pagando || eligiendoDirecto;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: colorScheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trato cerrado por ${formatearPrecio(acuerdo.precioAcordado)}. '
            '¿Cómo querés coordinar el pago?',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (leyendaPago != null) ...[
            const SizedBox(height: 2),
            Text(
              leyendaPago,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compra protegida',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Identidad verificada y pago resguardado hasta confirmar '
                  'la entrega. Pasamanos cobra una comisión del 5%.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: ocupado ? null : onPagar,
                    icon: pagando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payments_outlined),
                    label: const Text(
                      'Pagar con Mercado Pago',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trato directo',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Coordinan el pago y la entrega por su cuenta. Gratis, '
                  'sin verificación y sin protección de Pasamanos.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: ocupado ? null : onElegirDirecto,
                    icon: eligiendoDirecto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text(
                      'Coordinar por WhatsApp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Espejo de [_BannerElegirCamino] pero para la vendedora: sin esto no
/// tenía ninguna señal de que el trato está esperando que la compradora
/// elija un camino (el otro banner solo se mostraba del lado de quien
/// elige), lo que la dejaba sin saber si algo se rompió o si solo hay que
/// esperar. No tiene botón — acá no hay nada que la vendedora pueda hacer
/// más que esperar la elección de la otra parte.
class _BannerEsperandoPago extends StatelessWidget {
  const _BannerEsperandoPago({required this.acuerdo});

  final Acuerdo acuerdo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final leyenda = switch (acuerdo.estadoPago) {
      'pending' || 'in_process' => 'El pago está en proceso.',
      'rejected' =>
        'El pago fue rechazado — la compradora puede intentar de nuevo.',
      _ =>
        'Esperando que la compradora elija pagar con Mercado Pago o '
        'coordinar directo por WhatsApp.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              leyenda,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CTA para la vendedora una vez que el pago quedó aprobado: coordinar la
/// entrega (por WhatsApp, en el banner de abajo) y recién ahí marcar como
/// vendido. Separado de "Cancelar reserva" (que quedó en el AppBar) porque
/// son acciones casi opuestas y antes convivían en el mismo menú, fácil de
/// confundir.
class _BannerMarcarVendido extends StatelessWidget {
  const _BannerMarcarVendido({
    required this.coordinacionDirecta,
    required this.procesando,
    required this.onMarcarVendido,
  });

  final bool coordinacionDirecta;
  final bool procesando;
  final VoidCallback onMarcarVendido;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            coordinacionDirecta
                ? 'Coordiná la entrega y marcá como vendido cuando esté '
                      'lista.'
                : 'Pago confirmado. Coordiná la entrega y marcá como '
                      'vendido cuando esté lista.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: procesando ? null : onMarcarVendido,
              icon: procesando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Marcar como vendido'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Franja de aviso cuando el trato supera el monto que exige verificar la
/// identidad y todavía no se completó — se muestra tanto a la compradora
/// como a la vendedora, ya que cualquiera de las dos puede necesitar
/// verificarse antes de seguir adelante.
class _BannerDeVerificacion extends StatelessWidget {
  const _BannerDeVerificacion({required this.onIrAVerificar});

  final VoidCallback onIrAVerificar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: colorScheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Este trato supera ${formatearPrecio(montoMinimoVerificacion)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Por seguridad, verificá tu identidad antes de coordinar la '
            'entrega o el pago.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onIrAVerificar,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Verificar identidad'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Franja para compartir WhatsApp, habilitada recién cuando el trato está
/// cerrado (o completado) y, si el monto lo exige, la persona ya se
/// verificó. Cada quien comparte únicamente su propio número — ver
/// [[acuerdo_repository]] `compartirTelefono` — así que acá conviven dos
/// estados independientes: el propio (compartido o no) y el de la otra
/// parte (visible recién cuando ella lo compartió).
class _BannerWhatsapp extends StatelessWidget {
  const _BannerWhatsapp({
    required this.miTelefono,
    required this.otroTelefono,
    required this.compartiendo,
    required this.onCompartir,
    required this.onAbrir,
  });

  final String? miTelefono;
  final String? otroTelefono;
  final bool compartiendo;
  final VoidCallback onCompartir;
  final VoidCallback? onAbrir;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: colorScheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'WhatsApp',
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (miTelefono == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: compartiendo ? null : onCompartir,
                icon: compartiendo
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Compartir mi WhatsApp'),
              ),
            )
          else
            Text(
              'Compartiste tu WhatsApp.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (otroTelefono != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAbrir,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Abrir WhatsApp'),
              ),
            ),
          ] else if (miTelefono != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Esperando que la otra parte comparta el suyo.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Franja para calificar a la otra parte, una vez que el trato quedó
/// "completado" (venta confirmada). Desaparece sola apenas se envía la
/// calificación — el promedio que se ve en el perfil público lo recalcula
/// siempre el backend, nunca el cliente.
class _BannerCalificar extends StatelessWidget {
  const _BannerCalificar({required this.enviando, required this.onCalificar});

  final bool enviando;
  final VoidCallback onCalificar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Icon(Icons.star_outline_rounded, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¿Cómo te fue con este trato?',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.tonal(
            onPressed: enviando ? null : onCalificar,
            child: enviando
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Calificar'),
          ),
        ],
      ),
    );
  }
}
