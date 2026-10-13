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
    // Circular, como se ve el icono real en la mayoria de los launchers de
    // Android (forma adaptativa) -- el dibujo (percha + corazon) ya queda
    // centrado dentro del cuadrado, asi que recortarlo en circulo solo
    // saca las esquinas de fondo azul, sin tocar el dibujo en si.
    return ClipOval(
      child: Image.asset(
        'assets/icon/icon.png',
        width: tamanio,
        height: tamanio,
        fit: BoxFit.cover,
      ),
    );
  }
}
