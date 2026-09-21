import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

class PasamanosApp extends StatelessWidget {
  const PasamanosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasamanos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Fijado en claro: el modo oscuro nunca se vio en un dispositivo real
      // todavía, así que hasta no revisarlo a propósito no debe activarse
      // solo porque el teléfono tenga el sistema en oscuro.
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}
