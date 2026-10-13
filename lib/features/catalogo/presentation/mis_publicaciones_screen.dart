import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/publicacion.dart';
import 'publicacion_detail_screen.dart';
import 'publicacion_list_tile.dart';
import 'publicar_producto_screen.dart';
import '../providers/catalogo_providers.dart';
import '../../perfil/models/user_profile.dart';
import '../../perfil/providers/perfil_providers.dart';

/// Panel de la vendedora: sus publicaciones, estadísticas (activas, vistas) y
/// la tarjeta de onboarding (confirmar email, verificar identidad, conectar
/// Mercado Pago). Antes vivía adentro de HomeScreen junto con la búsqueda y
/// los accesos a Favoritos/Mensajes/Alertas — se separó en su propia pestaña
/// para que "Inicio" sea pura navegación de compra.
class MisPublicacionesScreen extends ConsumerStatefulWidget {
  const MisPublicacionesScreen({super.key, required this.onIrAPerfil});

  /// La tarjeta de onboarding manda acá ("Verificá tu identidad", "Conectá
  /// Mercado Pago") — como Perfil ahora es una pestaña del shell y no una
  /// pantalla empujada con Navigator, quien arma el shell decide qué hacer
  /// (cambiar de pestaña) en vez de que esta pantalla sepa nada de eso.
  final VoidCallback onIrAPerfil;

  @override
  ConsumerState<MisPublicacionesScreen> createState() =>
      MisPublicacionesScreenState();
}

class MisPublicacionesScreenState
    extends ConsumerState<MisPublicacionesScreen> {
  List<Publicacion> _publicaciones = [];
  bool _cargandoPublicaciones = true;
  bool _errorPublicaciones = false;

  /// Filtro activado al tocar la tarjeta "Activas".
  bool _soloActivas = false;

  /// Orden activado al tocar la tarjeta "Vistas totales" — mostrar qué
  /// publicación atrae más vistas es más útil que solo explicar el número
  /// en un diálogo.
  bool _ordenarPorVistas = false;

  UserProfile? _perfil;
  bool _mpConectada = false;

  /// Arranca en `true` (optimista) para no mostrar el aviso de "confirmá
  /// tu email" ni por un instante mientras se carga el estado real —
  /// recién se pone en `false` si `refrescarUsuario` confirma que de
  /// verdad falta confirmarlo.
  bool _emailVerificado = true;

  @override
  void initState() {
    super.initState();
    _cargarMisPublicaciones();
    _cargarEstadoOnboarding();
  }

  /// Público para que el shell lo llame cuando esta pestaña vuelve a quedar
  /// visible (p. ej. al volver de "Mi perfil" después de verificar la
  /// identidad o conectar Mercado Pago) — al usar IndexedStack entre
  /// pestañas no hay ningún ciclo de vida de "reaparecí" que dispare esto
  /// solo.
  Future<void> recargarEstado() async {
    await Future.wait([
      _cargarMisPublicaciones(),
      _cargarEstadoOnboarding(),
    ]);
  }

  Future<void> _cargarEstadoOnboarding() async {
    final authRepository = ref.read(authRepositoryProvider);
    final usuario = authRepository.currentUser;
    if (usuario == null) return;
    final resultados = await Future.wait([
      ref.read(userProfileRepositoryProvider).obtenerPorId(usuario.uid),
      ref.read(mercadoPagoRepositoryProvider).estaConectada(usuario.uid),
      // No alcanza con `usuario.emailVerificado`: ese viene del estado en
      // memoria, que puede estar desactualizado si confirmó el mail en
      // otra sesión — `refrescarUsuario` lo vuelve a pedir a Firebase.
      authRepository.refrescarUsuario(),
    ]);
    if (mounted) {
      setState(() {
        _perfil = resultados[0] as UserProfile?;
        _mpConectada = resultados[1] as bool;
        _emailVerificado = (resultados[2] as AppUser?)?.emailVerificado ?? true;
      });
    }
  }

  Future<void> _reenviarVerificacionEmail() async {
    try {
      await ref.read(authRepositoryProvider).reenviarVerificacionEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te volvimos a mandar el mail.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo reenviar el mail. Probá de nuevo en un rato.'),
          ),
        );
      }
    }
  }

  Future<void> _revisarEmailConfirmado() async {
    final usuario = await ref.read(authRepositoryProvider).refrescarUsuario();
    if (!mounted) return;
    setState(() => _emailVerificado = usuario?.emailVerificado ?? false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _emailVerificado
              ? '¡Listo, tu email ya está confirmado!'
              : 'Todavía no figura confirmado. Revisá tu bandeja de entrada.',
        ),
      ),
    );
  }

  Future<void> _ocultarOnboarding() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    setState(() {
      final perfil = _perfil;
      if (perfil != null) {
        _perfil = UserProfile(
          uid: perfil.uid,
          nombre: perfil.nombre,
          email: perfil.email,
          fotoUrl: perfil.fotoUrl,
          telefono: perfil.telefono,
          estadoVerificacion: perfil.estadoVerificacion,
          calificacionPromedio: perfil.calificacionPromedio,
          cantidadTransacciones: perfil.cantidadTransacciones,
          fechaRegistro: perfil.fechaRegistro,
          kycSessionId: perfil.kycSessionId,
          notificacionesActivas: perfil.notificacionesActivas,
          onboardingOculto: true,
        );
      }
    });
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .ocultarOnboarding(usuario.uid);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'MisPublicacionesScreen._ocultarOnboarding error: $error\n$stackTrace',
        );
      }
    }
  }

  // Estado propio (no un Future de un solo uso) justamente para poder
  // ofrecer "pull to refresh": un RefreshIndicator necesita volver a pedir
  // los datos sin reemplazar toda la pantalla por un spinner mientras
  // tanto — con un FutureBuilder, cambiar el Future de vuelta a "waiting"
  // hace parpadear toda la lista existente en cada refresco.
  Future<void> _cargarMisPublicaciones() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) {
      if (mounted) {
        setState(() {
          _publicaciones = [];
          _cargandoPublicaciones = false;
          _errorPublicaciones = false;
        });
      }
      return;
    }
    try {
      final lista = await ref
          .read(publicacionRepositoryProvider)
          .listarPorVendedor(usuario.uid);
      if (mounted) {
        setState(() {
          _publicaciones = lista;
          _cargandoPublicaciones = false;
          _errorPublicaciones = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargandoPublicaciones = false;
          _errorPublicaciones = true;
        });
      }
    }
  }

  Future<void> _abrirDialogoConfirmarEmail() async {
    final accion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmá tu email'),
        content: const Text(
          'Te mandamos un mail cuando te registraste. Si no lo encontrás, '
          'podés pedir que te lo reenvíen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('reenviar'),
            child: const Text('Reenviar email'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('revisar'),
            child: const Text('Ya lo confirmé'),
          ),
        ],
      ),
    );
    if (accion == 'reenviar') {
      await _reenviarVerificacionEmail();
    } else if (accion == 'revisar') {
      await _revisarEmailConfirmado();
    }
  }

  Future<void> _irAPublicar() async {
    final nuevaPublicacion = await Navigator.of(context).push<Publicacion>(
      MaterialPageRoute(builder: (_) => const PublicarProductoScreen()),
    );
    if (nuevaPublicacion == null) return;
    // Se agrega directo a la lista ya cargada en vez de volver a pedirle a
    // Firestore: así se ve al toque, sin esperar un segundo viaje de red.
    setState(() {
      _publicaciones = [nuevaPublicacion, ..._publicaciones];
    });
  }

  // El estado de una publicación puede cambiar en otra pantalla (p. ej.
  // "Marcar como vendido" desde el chat), así que al volver de cualquier
  // pantalla que pueda haber tocado eso, se refresca la lista — si no,
  // esta lista queda mostrando datos viejos hasta reabrir la app.
  Future<void> _verPublicacion(Publicacion publicacion) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicacionDetailScreen(publicacion: publicacion),
      ),
    );
    if (mounted) _cargarMisPublicaciones();
  }

  String get _tituloListaPublicaciones {
    if (_soloActivas && _ordenarPorVistas) {
      return 'Activas, ordenadas por vistas';
    }
    if (_soloActivas) return 'Mis publicaciones activas';
    if (_ordenarPorVistas) return 'Mis publicaciones, ordenadas por vistas';
    return 'Mis publicaciones';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis publicaciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAPublicar,
        icon: const Icon(Icons.add),
        label: const Text('Publicar producto'),
      ),
      body: Builder(
        builder: (context) {
          if (_cargandoPublicaciones) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_errorPublicaciones) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              mensaje: 'No se pudieron cargar tus publicaciones.',
            );
          }
          final publicaciones = _publicaciones;
          final perfil = _perfil;
          final mostrarOnboarding =
              perfil != null &&
              !perfil.onboardingOculto &&
              (!_emailVerificado ||
                  perfil.estadoVerificacion != EstadoVerificacion.verificado ||
                  !_mpConectada);
          final vistasTotales = publicaciones.fold<int>(
            0,
            (suma, p) => suma + p.vistas,
          );
          final activas = publicaciones
              .where((p) => p.estado == EstadoPublicacion.disponible)
              .length;
          final publicacionesAMostrar = _soloActivas
              ? publicaciones
                    .where((p) => p.estado == EstadoPublicacion.disponible)
                    .toList()
              : List<Publicacion>.from(publicaciones);
          if (_ordenarPorVistas) {
            publicacionesAMostrar.sort((a, b) => b.vistas.compareTo(a.vistas));
          }

          return RefreshIndicator(
            onRefresh: recargarEstado,
            child: ListView(
              // Sin esto, con pocas publicaciones (lista más corta que la
              // pantalla) el gesto de "pull to refresh" no se reconoce: la
              // physics por defecto solo lo habilita cuando hay contenido
              // de sobra para hacer scroll.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (mostrarOnboarding) ...[
                  _TarjetaOnboarding(
                    emailVerificado: _emailVerificado,
                    identidadVerificada:
                        perfil.estadoVerificacion ==
                        EstadoVerificacion.verificado,
                    mpConectada: _mpConectada,
                    onConfirmarEmail: _abrirDialogoConfirmarEmail,
                    onIrAPerfil: widget.onIrAPerfil,
                    onCerrar: _ocultarOnboarding,
                  ),
                  const SizedBox(height: 18),
                ],
                if (activas > 0 || vistasTotales > 0) ...[
                  Row(
                    children: [
                      if (activas > 0)
                        Expanded(
                          child: _TarjetaAccion(
                            icono: Icons.inventory_2_rounded,
                            etiqueta: 'Activas',
                            valor: '$activas',
                            color: colorScheme.primaryContainer,
                            colorTexto: colorScheme.onPrimaryContainer,
                            seleccionado: _soloActivas,
                            onTap: () =>
                                setState(() => _soloActivas = !_soloActivas),
                          ),
                        ),
                      if (activas > 0 && vistasTotales > 0)
                        const SizedBox(width: 10),
                      if (vistasTotales > 0)
                        Expanded(
                          child: _TarjetaAccion(
                            icono: Icons.visibility_rounded,
                            etiqueta: 'Vistas totales',
                            valor: '$vistasTotales',
                            color: colorScheme.secondaryContainer,
                            colorTexto: colorScheme.onSecondaryContainer,
                            seleccionado: _ordenarPorVistas,
                            onTap: () => setState(
                              () => _ordenarPorVistas = !_ordenarPorVistas,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                // Sin filtro activo no hace falta repetir el título: el
                // AppBar ya dice "Mis publicaciones" — esta fila solo
                // aparece para aclarar qué filtro/orden está aplicado y
                // ofrecer deshacerlo.
                if (_soloActivas || _ordenarPorVistas) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tituloListaPublicaciones,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _soloActivas = false;
                          _ordenarPorVistas = false;
                        }),
                        child: const Text('Ver todas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (publicaciones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          mensaje: 'Todavía no publicaste nada.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _irAPublicar,
                          icon: const Icon(Icons.add),
                          label: const Text('Publicar mi primer producto'),
                        ),
                      ],
                    ),
                  )
                else if (publicacionesAMostrar.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      mensaje: 'No tenés publicaciones activas ahora mismo.',
                    ),
                  )
                else
                  ...publicacionesAMostrar.map(
                    (publicacion) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PublicacionListTile(
                        publicacion: publicacion,
                        mostrarVistas: true,
                        onTap: () => _verPublicacion(publicacion),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tile único para la acción (Publicar) y estadísticas (Activas, Vistas
/// totales): mismo estilo visual — fondo de color sólido, ícono y texto
/// centrados — para que el dashboard se vea coherente. Si lleva [valor], se
/// ve como estadística (con el número grande).
class _TarjetaAccion extends StatelessWidget {
  const _TarjetaAccion({
    required this.icono,
    required this.etiqueta,
    required this.color,
    required this.colorTexto,
    this.valor,
    this.onTap,
    this.seleccionado = false,
  });

  final IconData icono;
  final String etiqueta;
  final Color color;
  final Color colorTexto;
  final String? valor;
  final VoidCallback? onTap;

  /// Si esta tarjeta actúa como filtro activo (p. ej. "Activas" cuando la
  /// lista de abajo ya está filtrada), se lo marca con un borde para que
  /// quede claro que está aplicado — sin esto no había ninguna señal de
  /// que tocarla hizo algo.
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, color: colorTexto),
        if (valor != null) ...[
          const SizedBox(height: 6),
          Text(
            valor!,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: colorTexto, fontWeight: FontWeight.w900),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: colorTexto, fontWeight: FontWeight.w700),
        ),
      ],
    );

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: seleccionado
              ? Border.all(color: colorTexto, width: 2)
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: contenido,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta para usuarias nuevas con los pasos que no son obligatorios para
/// usar la app pero sí para sacarle el jugo (confirmar el email, verificar
/// identidad, conectar Mercado Pago) — desaparece sola cuando todos los
/// pasos están completos, o si la usuaria la cierra a mano.
class _TarjetaOnboarding extends StatelessWidget {
  const _TarjetaOnboarding({
    required this.emailVerificado,
    required this.identidadVerificada,
    required this.mpConectada,
    required this.onConfirmarEmail,
    required this.onIrAPerfil,
    required this.onCerrar,
  });

  final bool emailVerificado;
  final bool identidadVerificada;
  final bool mpConectada;
  final VoidCallback onConfirmarEmail;
  final VoidCallback onIrAPerfil;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Completá tu cuenta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCerrar,
                tooltip: 'No volver a mostrar',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          _FilaOnboarding(
            hecho: emailVerificado,
            texto: 'Confirmá tu email',
            onTap: onConfirmarEmail,
          ),
          _FilaOnboarding(
            hecho: identidadVerificada,
            texto: 'Verificá tu identidad para compras protegidas',
            onTap: onIrAPerfil,
          ),
          _FilaOnboarding(
            hecho: mpConectada,
            texto: 'Conectá Mercado Pago para cobrar tus ventas',
            onTap: onIrAPerfil,
          ),
        ],
      ),
    );
  }
}

class _FilaOnboarding extends StatelessWidget {
  const _FilaOnboarding({
    required this.hecho,
    required this.texto,
    required this.onTap,
  });

  final bool hecho;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: hecho ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              hecho
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  decoration: hecho ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!hecho)
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
          ],
        ),
      ),
    );
  }
}
