import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pasamanos_icon_painter.dart';

/// El mismo glifo (percha + corazon) del icono real de la app, para
/// usar dentro de la interfaz -- login, pantallas de bienvenida, etc. --
/// en vez de un icono generico de Material que no tiene nada que ver con
/// la marca. Reusar el glifo real (ya probado en el icono de la app y el
/// feature graphic de la tienda) da una identidad visual consistente en
/// vez de uno distinto por pantalla.
class LogoPasamanos extends StatelessWidget {
  const LogoPasamanos({super.key, this.tamanio = 72});

  final double tamanio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanio,
      height: tamanio,
      decoration: BoxDecoration(
        color: AppTheme.azulMarca,
        borderRadius: BorderRadius.circular(tamanio * 0.33),
      ),
      child: CustomPaint(
        painter: PasamanosIconPainter(
          colorFondo: null,
          colorGlifo: Colors.white,
          colorAcento: AppTheme.coralMarca,
          factorEscala: 0.62,
        ),
      ),
    );
  }
}
