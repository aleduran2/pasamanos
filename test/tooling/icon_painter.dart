import 'package:flutter/material.dart';

/// Glifo del ícono de la app: un percherito (símbolo universal de "ropa" /
/// marketplace de indumentaria) con un corazón como dije — más llamativo y
/// "de marca" que un pictograma abstracto, y sigue leyéndose como "ropa
/// entre familias". Coordenadas normalizadas 0..100.
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

    Offset p(double x, double y) => Offset(x * escala, y * escala) + desplazamiento;
    double e(double v) => v * escala;

    final trazoGancho = Paint()
      ..color = colorGlifo
      ..style = PaintingStyle.stroke
      ..strokeWidth = e(6)
      ..strokeCap = StrokeCap.round;

    final trazoPercha = Paint()
      ..color = colorGlifo
      ..style = PaintingStyle.stroke
      ..strokeWidth = e(11)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Gancho de la percha: un arco abierto hacia abajo, con las puntas
    // cerca del vértice de la "V" para que se vean como una sola pieza.
    final gancho = Path()
      ..moveTo(p(46, 33).dx, p(46, 33).dy)
      ..cubicTo(
        p(38, 33).dx,
        p(38, 33).dy,
        p(37, 14).dx,
        p(37, 14).dy,
        p(50, 14).dx,
        p(50, 14).dy,
      )
      ..cubicTo(
        p(63, 14).dx,
        p(63, 14).dy,
        p(62, 33).dx,
        p(62, 33).dy,
        p(54, 33).dx,
        p(54, 33).dy,
      );
    canvas.drawPath(gancho, trazoGancho);

    // Cuerpo de la percha: una "V" con las puntas hacia arriba levemente
    // curvadas, como los brazos de una percha real.
    final percha = Path()
      ..moveTo(p(12, 66).dx, p(12, 66).dy)
      ..quadraticBezierTo(
        p(18, 58).dx,
        p(18, 58).dy,
        p(50, 34).dx,
        p(50, 34).dy,
      )
      ..quadraticBezierTo(
        p(82, 58).dx,
        p(82, 58).dy,
        p(88, 66).dx,
        p(88, 66).dy,
      );
    canvas.drawPath(percha, trazoPercha);

    // Barra de la percha (donde colgaría la ropa).
    canvas.drawLine(p(22, 66), p(78, 66), trazoPercha);

    // Corazón como dije, apoyado sobre la barra.
    const cx = 50.0, cy = 56.0, r = 9.0;
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
