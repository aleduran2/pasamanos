import 'package:flutter/material.dart';

/// Glifo del ícono de la app: doble lectura a propósito — un gancho de
/// percha (ropa) apoyado sobre una silueta con forma de prenda/torso
/// (gente que revende su ropa), con un corazón como dije. Coordenadas
/// normalizadas 0..100.
///
/// A diferencia de la versión anterior (dos líneas finas formando una
/// "V"), acá el cuerpo es una silueta RELLENA con forma de campana —
/// como una prenda colgando (pollera/poncho) y, a la vez, como el
/// contorno de hombros y torso de una persona. Un relleno sólido se lee
/// más claro a tamaños chicos que dos trazos delgados con un hueco en
/// el medio, que es lo que hacía que el significado quedara "abstracto".
class PasamanosIconPainter extends CustomPainter {
  const PasamanosIconPainter({
    required this.colorFondo,
    required this.colorGlifo,
    required this.colorAcento,
    this.factorEscala = 0.62,
  });

  final Color? colorFondo;
  final Color colorGlifo;
  final Color colorAcento;
  final double factorEscala;

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = colorFondo;
    if (fondo != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = fondo);
    }

    final lado = size.shortestSide;
    final escala = (lado / 100) * factorEscala;
    final desplazamiento = Offset(
      (size.width - 100 * escala) / 2,
      (size.height - 100 * escala) / 2,
    );

    Offset p(double x, double y) =>
        Offset(x * escala, y * escala) + desplazamiento;
    double e(double v) => v * escala;

    // Gancho: aro abierto (no un círculo cerrado) apoyado sobre el
    // vértice de la silueta — se lee como el gancho de metal de una
    // percha real. El centro se calcula para que el borde inferior del
    // aro toque justo el vértice del triángulo (36), sin espacio en
    // blanco entre las dos piezas.
    const centroGanchoY = 36.0 - 7.5 + 1;
    final trazoGancho = Paint()
      ..color = colorGlifo
      ..style = PaintingStyle.stroke
      ..strokeWidth = e(7)
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromCircle(center: p(50, centroGanchoY), radius: e(7.5)),
      trazoGancho,
    );

    // Silueta rellena en forma de "V"/triángulo (brazos rectos, como los
    // de una percha real) con esquinas inferiores redondeadas. Antes
    // medía ~62 unidades de ancho por ~36 de alto (una relación de
    // ~1.7:1) — una percha real es bastante más ancha que alta, así que
    // se ensanchó a ~84 de ancho por ~28 de alto (~3:1), más aplanada.
    final silueta = Path()
      ..moveTo(p(50, 36).dx, p(50, 36).dy)
      ..lineTo(p(9, 60).dx, p(9, 60).dy)
      ..quadraticBezierTo(
        p(4, 65).dx,
        p(4, 65).dy,
        p(13, 67).dx,
        p(13, 67).dy,
      )
      ..lineTo(p(87, 67).dx, p(87, 67).dy)
      ..quadraticBezierTo(
        p(96, 65).dx,
        p(96, 65).dy,
        p(91, 60).dx,
        p(91, 60).dy,
      )
      ..lineTo(p(50, 36).dx, p(50, 36).dy)
      ..close();
    canvas.drawPath(silueta, Paint()..color = colorGlifo);

    // Corazón como dije, sobre el "pecho" de la silueta (más chico que
    // antes: el triángulo ahora es más bajo, así que hay menos alto
    // disponible en el medio).
    const cx = 50.0, cy = 51.0, r = 8.5;
    final corazon = Path()
      ..moveTo(p(cx, cy + r * 1.35).dx, p(cx, cy + r * 1.35).dy)
      ..cubicTo(
        p(cx - r * 2.2, cy - r * 0.4).dx,
        p(cx - r * 2.2, cy - r * 0.4).dy,
        p(cx - r * 0.9, cy - r * 1.6).dx,
        p(cx - r * 0.9, cy - r * 1.6).dy,
        p(cx, cy - r * 0.35).dx,
        p(cx, cy - r * 0.35).dy,
      )
      ..cubicTo(
        p(cx + r * 0.9, cy - r * 1.6).dx,
        p(cx + r * 0.9, cy - r * 1.6).dy,
        p(cx + r * 2.2, cy - r * 0.4).dx,
        p(cx + r * 2.2, cy - r * 0.4).dy,
        p(cx, cy + r * 1.35).dx,
        p(cx, cy + r * 1.35).dy,
      )
      ..close();
    canvas.drawPath(corazon, Paint()..color = colorAcento);
  }

  @override
  bool shouldRepaint(covariant PasamanosIconPainter oldDelegate) => false;
}
