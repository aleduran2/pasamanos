import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogo_botones.dart';
import '../../../core/widgets/empty_state.dart';
import '../../alertas/presentation/alertas_screen.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../busqueda/presentation/busqueda_screen.dart';
import '../../catalogo/models/publicacion.dart';
import '../../catalogo/presentation/publicacion_detail_screen.dart';
import '../../catalogo/presentation/publicacion_list_tile.dart';
import '../../catalogo/presentation/publicar_producto_screen.dart';
import '../../catalogo/providers/catalogo_providers.dart';
import '../../chat/models/conversacion.dart';
import '../../chat/presentation/conversaciones_screen.dart';
import '../../chat/providers/chat_providers.dart';
import '../../favoritos/presentation/favoritos_screen.dart';
import '../../notificaciones/providers/notificaciones_providers.dart';
import '../../perfil/presentation/perfil_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<List<Publicacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargarMisPublicaciones();
    _registrarNotificaciones();
  }

  void _registrarNotificaciones() {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    ref.read(fcmTokenServiceProvider).registrarToken(usuario.uid);
  }

  Future<List<Publicacion>> _cargarMisPublicaciones() {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return Future.value(const []);
    return ref.read(publicacionRepositoryProvider).listarPorVendedor(usuario.uid);
  }

  Future<void> _irAPublicar() async {
    final nuevaPublicacion = await Navigator.of(context).push<Publicacion>(
      MaterialPageRoute(builder: (_) => const PublicarProductoScreen()),
    );
    if (nuevaPublicacion == null) return;
    // Se agrega directo a la lista ya cargada en vez de volver a pedirle a
    // Firestore: así se ve al toque, sin esperar un segundo viaje de red.
    setState(() {
      _futuro = _futuro.then((lista) => [nuevaPublicacion, ...lista]);
    });
  }

  // El estado de una publicación puede cambiar en otra pantalla (p. ej.
  // "Marcar como vendido" desde el chat), así que al volver de cualquier
  // pantalla que pueda haber tocado eso, se refresca la lista — si no,
  // "Mis publicaciones" queda mostrando datos viejos hasta reabrir la app.
  Future<void> _irAConversaciones() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ConversacionesScreen()));
    if (mounted) {
      setState(() {
        _futuro = _cargarMisPublicaciones();
      });
    }
  }

  Future<void> _verPublicacion(Publicacion publicacion) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicacionDetailScreen(publicacion: publicacion),
      ),
    );
    if (mounted) {
      setState(() {
        _futuro = _cargarMisPublicaciones();
      });
    }
  }

  Future<void> _irAPerfil() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PerfilScreen()));
    // El nombre/foto pueden haber cambiado en "Mi perfil" — refresca para
    // que el encabezado de acá no se quede mostrando datos viejos.
    if (mounted) setState(() {});
  }

  Future<void> _cerrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Querés cerrar tu sesión en Pasamanos?'),
        actions: [
          DialogoBotones(
            textoCancelar: 'Cancelar',
            textoConfirmar: 'Cerrar sesión',
            onCancelar: () => Navigator.of(context).pop(false),
            onConfirmar: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usuario = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasamanos'),
        actions: [
          if (usuario != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MenuPerfil(
                usuario: usuario,
                onPerfil: _irAPerfil,
                onCerrarSesion: _cerrarSesion,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAPublicar,
        icon: const Icon(Icons.add),
        label: const Text('Publicar producto'),
      ),
      body: FutureBuilder<List<Publicacion>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              mensaje: 'No se pudieron cargar tus publicaciones.',
            );
          }
          final publicaciones = snapshot.data ?? [];
          final vistasTotales = publicaciones.fold<int>(
            0,
            (suma, p) => suma + p.vistas,
          );
          final activas = publicaciones
              .where((p) => p.estado == EstadoPublicacion.disponible)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _BarraDeBusqueda(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BusquedaScreen()),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _TarjetaAccion(
                      icono: Icons.favorite_rounded,
                      etiqueta: 'Favoritos',
                      color: colorScheme.primaryContainer,
                      colorTexto: colorScheme.onPrimaryContainer,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FavoritosScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: usuario == null
                        ? _TarjetaAccion(
                            icono: Icons.chat_bubble_rounded,
                            etiqueta: 'Mensajes',
                            color: colorScheme.secondaryContainer,
                            colorTexto: colorScheme.onSecondaryContainer,
                            onTap: _irAConversaciones,
                          )
                        : StreamBuilder<List<Conversacion>>(
                            stream: ref
                                .read(chatRepositoryProvider)
                                .misConversaciones(usuario.uid),
                            builder: (context, snapshot) {
                              final sinLeer = (snapshot.data ?? const [])
                                  .where((c) => c.noLeidoPor(usuario.uid))
                                  .length;
                              return _TarjetaAccion(
                                icono: Icons.chat_bubble_rounded,
                                etiqueta: 'Mensajes',
                                color: colorScheme.secondaryContainer,
                                colorTexto: colorScheme.onSecondaryContainer,
                                onTap: _irAConversaciones,
                                badge: sinLeer,
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TarjetaAccion(
                      icono: Icons.notifications_active_rounded,
                      etiqueta: 'Alertas',
                      color: colorScheme.primaryContainer,
                      colorTexto: colorScheme.onPrimaryContainer,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AlertasScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              if (activas > 0 || vistasTotales > 0) ...[
                const SizedBox(height: 10),
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
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Mis publicaciones',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
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
              else
                ...publicaciones.map(
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
          );
        },
      ),
    );
  }
}

/// Avatar en el AppBar con un menú desplegable — antes "Mi perfil" y
/// "Cerrar sesión" eran dos íconos sueltos (uno de ellos, encima, sin
/// ningún dato de la usuaria a la vista). Acá el propio avatar hace de
/// disparador del menú, un patrón más habitual en apps con cuenta.
class _MenuPerfil extends StatelessWidget {
  const _MenuPerfil({
    required this.usuario,
    required this.onPerfil,
    required this.onCerrarSesion,
  });

  final AppUser usuario;
  final VoidCallback onPerfil;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<VoidCallback>(
      tooltip: 'Mi cuenta',
      onSelected: (accion) => accion(),
      icon: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: usuario.fotoUrl != null
            ? NetworkImage(usuario.fotoUrl!)
            : null,
        child: usuario.fotoUrl == null
            ? Icon(Icons.person_rounded, color: colorScheme.onSurfaceVariant)
            : null,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: onPerfil,
          child: const Row(
            children: [
              Icon(Icons.person_outline_rounded),
              SizedBox(width: 12),
              Text('Mi perfil'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: onCerrarSesion,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Cerrar sesión', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarraDeBusqueda extends StatelessWidget {
  const _BarraDeBusqueda({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                'Buscar ropa, uniformes, juguetes...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile único para acciones rápidas (Favoritos, Mensajes) y estadísticas
/// (Activas, Vistas totales): mismo estilo visual — fondo de color sólido,
/// ícono y texto centrados — para que el dashboard se vea coherente en vez
/// de mezclar dos lenguajes visuales distintos. Si lleva [valor], se ve
/// como estadística (con el número grande); si no, como acción (tocable).
class _TarjetaAccion extends StatelessWidget {
  const _TarjetaAccion({
    required this.icono,
    required this.etiqueta,
    required this.color,
    required this.colorTexto,
    this.valor,
    this.onTap,
    this.badge,
  });

  final IconData icono;
  final String etiqueta;
  final Color color;
  final Color colorTexto;
  final String? valor;
  final VoidCallback? onTap;

  /// Cantidad a mostrar en el globito rojo arriba a la derecha (p. ej.
  /// conversaciones sin leer) — sin esto, la vendedora no tenía ninguna
  /// forma de darse cuenta desde el Home que alguien le escribió, más que
  /// entrando a "Mensajes" a mirar.
  final int? badge;

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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorTexto,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorTexto,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final tarjeta = Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: onTap == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: contenido,
            )
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                child: contenido,
              ),
            ),
    );

    if (badge == null || badge == 0) return tarjeta;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Un Stack da a sus hijos no posicionados restricciones "loose" en
        // vez de las "tight" que daba el Expanded de antes — sin este
        // SizedBox la tarjeta se encoge a su contenido y el badge, ubicado
        // relativo al Stack entero, queda flotando lejos de ella.
        SizedBox(width: double.infinity, child: tarjeta),
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
            child: Text(
              badge! > 9 ? '9+' : '$badge',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
