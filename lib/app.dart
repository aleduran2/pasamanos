import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/home_placeholder_screen.dart';

class PasamanosApp extends StatelessWidget {
  const PasamanosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasamanos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePlaceholderScreen(),
    );
  }
}
