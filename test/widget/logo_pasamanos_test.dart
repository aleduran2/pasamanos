import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/core/widgets/logo_pasamanos.dart';

void main() {
  testWidgets(
    'se mantiene cuadrado incluso dentro de un ListView (que fuerza el '
    'ancho de sus hijos)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [Center(child: LogoPasamanos())],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(LogoPasamanos));
      expect(size, const Size(72, 72));
    },
  );
}
