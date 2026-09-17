import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';

class PasamanosApp extends StatelessWidget {
  const PasamanosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasamanos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // TODO(fase-1b): cambiar a AuthGate cuando main.dart llame a
      // Firebase.initializeApp() con el proyecto real. Hasta entonces,
      // los botones de esta pantalla van a fallar al tocarlos (no hay
      // backend configurado todavía), pero la UI se puede revisar.
      home: const LoginScreen(),
    );
  }
}
