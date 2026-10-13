import 'package:flutter/material.dart';

/// El icono real de la app (assets/icon/icon.png), para usar dentro de la
/// interfaz -- login, pantallas de bienvenida, etc. -- en vez de un icono
/// generico de Material que no tiene nada que ver con la marca. Es el
/// mismo archivo que usa flutter_launcher_icons para generar el icono
/// instalado, asi que coincide pixel a pixel con lo que la usuaria ve en
/// su pantalla de inicio -- no una version aparte que se puede desalinear
/// con el tiempo.
class LogoPasamanos extends StatelessWidget {
  const LogoPasamanos({super.key, this.tamanio = 72});

  final double tamanio;

  @override
  Widget build(BuildContext context) {
    // Sin ClipRRect propio a proposito: el archivo ya trae esquinas
    // redondeadas dibujadas -- enmascarar de nuevo con un radio distinto
    // al que ya tiene el dibujo generaria un desajuste visible entre las
    // dos curvas.
    return Image.asset(
      'assets/icon/icon.png',
      width: tamanio,
      height: tamanio,
      fit: BoxFit.cover,
    );
  }
}
