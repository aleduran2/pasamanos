// Herramienta de desarrollo, no un test de comportamiento: renderiza el
// "feature graphic" de Play Store (1024x500, sin canal alfa) y una versión
// de 512x512 del ícono de la tienda, reusando el glifo de
// `PasamanosIconPainter` para que ambos queden visualmente consistentes con
// el ícono real de la app. Se corre a mano, no forma parte de la suite
// normal de tests.
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
  required Widget widget,
  required double width,
  required double height,
  required String rutaSalida,
}) async {
  // Sin esto, el tamaño real disponible es el de la superficie de test por
  // defecto (más chica que lo que pedimos acá), y un Row/Column con texto
  // adentro tira overflow en vez de quedar del tamaño pedido.
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: SizedBox(width: width, height: height, child: widget),
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
  testWidgets('genera store/feature_graphic.png (1024x500)', (tester) async {
    // Sin texto a propósito: renderizar fuentes reales en `flutter test`
    // no es confiable (el motor usa una fuente de reemplazo para
    // determinismo de goldens), y agregar el wordmark mete una
    // dependencia frágil para un asset que es solo "lindo tener". El
    // glifo solo, sobre el azul de marca, ya es un feature graphic válido.
    await _guardarPng(
      tester,
      width: 1024,
      height: 500,
      rutaSalida: 'store/feature_graphic.png',
      widget: Container(
        color: _azulPrimario,
        child: Center(
          child: SizedBox(
            width: 420,
            height: 420,
            child: CustomPaint(
              painter: PasamanosIconPainter(
                colorFondo: null,
                colorGlifo: Colors.white,
                colorAcento: _coralAcento,
                factorEscala: 0.9,
              ),
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('genera store/icono_tienda_512.png (512x512)', (tester) async {
    await _guardarPng(
      tester,
      width: 512,
      height: 512,
      rutaSalida: 'store/icono_tienda_512.png',
      widget: CustomPaint(
        painter: PasamanosIconPainter(
          colorFondo: _azulPrimario,
          colorGlifo: Colors.white,
          colorAcento: _coralAcento,
          factorEscala: 0.82,
        ),
      ),
    );
  });
}
