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
      home: const AuthGate(),
    );
  }
}
