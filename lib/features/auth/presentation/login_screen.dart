import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/campo_password.dart';
import '../../../core/widgets/dialogo_botones.dart';
import '../../../core/widgets/logo_pasamanos.dart';
import '../providers/auth_providers.dart';
import 'auth_error_messages.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // Le avisa al framework que el login terminó bien, para que Android
      // ofrezca guardar el usuario/contraseña en el administrador de
      // contraseñas del dispositivo.
      TextInput.finishAutofillContext();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeErrorAuth(error))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvideContrasena() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? error;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Restablecer contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresá tu email y te mandamos un link para poner una '
                'contraseña nueva.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
            ],
          ),
          actions: [
            DialogoBotones(
              textoCancelar: 'Cancelar',
              textoConfirmar: 'Enviar',
              onCancelar: () => Navigator.of(context).pop(false),
              onConfirmar: () {
                if (!emailController.text.trim().contains('@')) {
                  setDialogState(() => error = 'Ingresá un email válido');
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
    final email = emailController.text.trim();

    try {
      await ref.read(authRepositoryProvider).enviarResetContrasena(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Te mandamos un mail a $email.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeErrorAuth(error))));
      }
    }
  }

  Future<void> _continuarConGoogle() async {
    setState(() => _cargando = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('signInWithGoogle error: $error\n$stackTrace');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeErrorAuth(error))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: ListView(
                children: [
                  const SizedBox(height: 24),
                  const LogoPasamanos(),
                  const SizedBox(height: 20),
                  Text(
                    'Pasamanos',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ropa, uniformes y juguetes de chicos,\nentre familias de La Plata.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (valor) {
                      if (valor == null || !valor.contains('@')) {
                        return 'Ingresá un email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CampoPassword(
                    controller: _passwordController,
                    labelText: 'Contraseña',
                    autofillHints: const [AutofillHints.password],
                    validator: (valor) {
                      if (valor == null || valor.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _cargando ? null : _olvideContrasena,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _cargando ? null : _iniciarSesion,
                    child: _cargando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ingresar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _cargando ? null : _continuarConGoogle,
                    child: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: const Text('¿No tenés cuenta? Registrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
