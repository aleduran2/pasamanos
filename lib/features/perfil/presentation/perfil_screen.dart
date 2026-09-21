import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/kyc.dart';
import '../../auth/presentation/auth_error_messages.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalogo/providers/catalogo_providers.dart';
import '../models/user_profile.dart';
import '../providers/perfil_providers.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen>
    with WidgetsBindingObserver {
  bool _cargando = true;
  bool _conectada = false;
  bool _verificando = false;
  bool _guardandoTelefono = false;
  bool _guardandoNombre = false;
  bool _subiendoFoto = false;
  EstadoVerificacion _estadoVerificacion = EstadoVerificacion.noVerificado;
  final _telefonoController = TextEditingController();
  final _nombreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final usuario = ref.read(authRepositoryProvider).currentUser;
    _nombreController.text = usuario?.nombre ?? '';
    _cargarEstado();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telefonoController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del navegador (donde se autoriza en Mercado Pago), la app
    // pasa a "resumed" — es el mejor momento para revisar si ya se
    // conectó, ya que no hay forma de que el navegador nos avise solo.
    if (state == AppLifecycleState.resumed) _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    setState(() => _cargando = true);
    final resultados = await Future.wait([
      ref.read(mercadoPagoRepositoryProvider).estaConectada(usuario.uid),
      ref.read(userProfileRepositoryProvider).obtenerPorId(usuario.uid),
    ]);
    if (mounted) {
      setState(() {
        _conectada = resultados[0] as bool;
        final perfil = resultados[1] as UserProfile?;
        _estadoVerificacion =
            perfil?.estadoVerificacion ?? EstadoVerificacion.noVerificado;
        _telefonoController.text = perfil?.telefono ?? '';
        _cargando = false;
      });
    }
  }

  Future<void> _guardarTelefono() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;
    final telefono = _telefonoController.text.trim();
    if (telefono.isEmpty) return;

    setState(() => _guardandoTelefono = true);
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .actualizarTelefono(uid: usuario.uid, telefono: telefono);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp guardado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el WhatsApp.')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoTelefono = false);
    }
  }

  Future<void> _guardarNombre() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) return;

    setState(() => _guardandoNombre = true);
    try {
      await ref.read(authRepositoryProvider).actualizarNombre(nombre);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nombre actualizado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el nombre.')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoNombre = false);
    }
  }

  Future<void> _cambiarFoto() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Sacar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;

    final archivo = await ImagePicker().pickImage(
      source: origen,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (archivo == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final url = await ref
          .read(imageUploadServiceProvider)
          .subirAvatar(archivo: File(archivo.path), uid: usuario.uid);
      await ref.read(authRepositoryProvider).actualizarFoto(url);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _abrirDialogoCambiarContrasena() async {
    final actualController = TextEditingController();
    final nuevaController = TextEditingController();
    var enviando = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: actualController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nuevaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña nueva',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: enviando
                  ? null
                  : () async {
                      final actual = actualController.text;
                      final nueva = nuevaController.text;
                      if (nueva.length < 6) {
                        setDialogState(
                          () => error =
                              'La contraseña nueva debe tener al menos 6 caracteres.',
                        );
                        return;
                      }
                      setDialogState(() {
                        enviando = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(authRepositoryProvider)
                            .cambiarContrasena(actual: actual, nueva: nueva);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contraseña actualizada.'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          enviando = false;
                          error = mensajeErrorAuth(e);
                        });
                      }
                    },
              child: enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verificarIdentidad() async {
    setState(() => _verificando = true);
    try {
      final resultado = await FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('crearSesionVerificacion').call<Map<String, dynamic>>();
      final url = resultado.data['url'] as String?;
      if (url == null) throw Exception('Sin URL de verificación');

      final abierto = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!abierto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la verificación.')),
        );
      } else {
        setState(() => _estadoVerificacion = EstadoVerificacion.pendiente);
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'No se pudo iniciar la verificación.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la verificación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _conectarMercadoPago() async {
    final usuario = ref.read(authRepositoryProvider).currentUser;
    if (usuario == null) return;

    final clientId = dotenv.env['MERCADOPAGO_CLIENT_ID'];
    final redirectUri = dotenv.env['MERCADOPAGO_OAUTH_REDIRECT_URI'];
    if (clientId == null ||
        clientId.isEmpty ||
        redirectUri == null ||
        redirectUri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta configurar Mercado Pago (.env).'),
        ),
      );
      return;
    }

    final url = Uri.https('auth.mercadopago.com.ar', '/authorization', {
      'client_id': clientId,
      'response_type': 'code',
      'platform_id': 'mp',
      'redirect_uri': redirectUri,
      'state': usuario.uid,
    });

    final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Mercado Pago.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usuario = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (usuario != null) ...[
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    backgroundImage: usuario.fotoUrl != null
                        ? NetworkImage(usuario.fotoUrl!)
                        : null,
                    child: usuario.fotoUrl == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 44,
                            color: colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _subiendoFoto ? null : _cambiarFoto,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _subiendoFoto
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                  color: colorScheme.onPrimary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nombreController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _guardandoNombre ? null : _guardarNombre,
                  icon: _guardandoNombre
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              usuario.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (ref.read(authRepositoryProvider).tieneContrasena) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _abrirDialogoCambiarContrasena,
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Cambiar contraseña'),
              ),
            ],
            const SizedBox(height: 24),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mi WhatsApp',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Se comparte solo cuando vos elegís hacerlo, dentro de un '
                  'chat con un trato cerrado.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (_cargando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _telefonoController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Ej: 2211234567',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _guardandoTelefono ? null : _guardarTelefono,
                        icon: _guardandoTelefono
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_outlined, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Mercado Pago',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Conectá tu cuenta para poder cobrar directo cuando cierres '
                  'un trato. Pasamanos se queda con una comisión del 5% de '
                  'cada venta; el resto va directo a tu cuenta.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (_cargando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_conectada)
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Cuenta conectada',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: _conectarMercadoPago,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Conectar Mercado Pago'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Verificación de identidad',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Para tratos de ${_formatearMonto(montoMinimoVerificacion)} '
                  'o más, pedimos verificar tu identidad antes de compartir '
                  'contacto — es una medida de seguridad para todas las '
                  'familias de la comunidad.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (_cargando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  _EstadoKyc(
                    estado: _estadoVerificacion,
                    verificando: _verificando,
                    onVerificar: _verificarIdentidad,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatearMonto(double monto) => '\$${monto.toStringAsFixed(0)}';

class _EstadoKyc extends StatelessWidget {
  const _EstadoKyc({
    required this.estado,
    required this.verificando,
    required this.onVerificar,
  });

  final EstadoVerificacion estado;
  final bool verificando;
  final VoidCallback onVerificar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (estado) {
      case EstadoVerificacion.verificado:
        return Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Identidad verificada',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      case EstadoVerificacion.pendiente:
        return Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Verificación en proceso...',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        );
      case EstadoVerificacion.rechazado:
      case EstadoVerificacion.noVerificado:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (estado == EstadoVerificacion.rechazado) ...[
              Text(
                'La verificación anterior no se pudo confirmar. Podés intentar de nuevo.',
                style: TextStyle(color: colorScheme.error),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: verificando ? null : onVerificar,
              icon: verificando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Verificar identidad'),
            ),
          ],
        );
    }
  }
}
