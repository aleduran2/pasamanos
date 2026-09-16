import 'package:flutter/material.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pasamanos')),
      body: const Center(
        child: Text('Fase 0 completada — listo para Fase 1'),
      ),
    );
  }
}
