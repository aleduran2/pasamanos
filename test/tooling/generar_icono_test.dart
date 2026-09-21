// Herramienta de desarrollo, no un test de comportamiento: renderiza el
// glifo de `PasamanosIconPainter` a PNGs de 1024x1024 para usar como fuente
// de `flutter_launcher_icons`. Se corre a mano cuando hace falta regenerar
// el ícono (no forma parte de la suite normal de tests).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'icon_painter.dart';

const _azulPrimario = Color(0xFF2557D6);
const _coralAcento = Color(0xFFF4623A);

Future<void> _guardarPng(
  WidgetTester tester, {
  required Color? colorFondo,
  required double factorEscala,
  required String rutaSalida,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: SizedBox(
          width: 1024,
          height: 1024,
          child: CustomPaint(
            painter: PasamanosIconPainter(
              colorFondo: colorFondo,
              colorGlifo: Colors.white,
              colorAcento: _coralAcento,
              factorEscala: factorEscala,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = tester.renderObject(
      find.byType(RepaintBoundary),
    );
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final archivo = File(rutaSalida);
    archivo.parent.createSync(recursive: true);
    archivo.writeAsBytesSync(byteData!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('genera assets/icon/icon.png (ícono plano)', (tester) async {
    await _guardarPng(
      tester,
      colorFondo: _azulPrimario,
      factorEscala: 0.82,
      rutaSalida: 'assets/icon/icon.png',
    );
  });

  testWidgets('genera assets/icon/icon_foreground.png (adaptable)', (
    tester,
  ) async {
    // flutter_launcher_icons le suma un inset propio del 16% arriba de
    // esto, por eso acá va más grande que en el ícono plano: el resultado
    // final visible queda parejo con el de arriba.
    await _guardarPng(
      tester,
      colorFondo: null,
      factorEscala: 0.85,
      rutaSalida: 'assets/icon/icon_foreground.png',
    );
  });
}
