import 'package:flutter/material.dart';

/// Grilla pareja de 2 columnas: a diferencia de un `Wrap` de chips (cuyo
/// ancho depende del largo de cada etiqueta), acá todas las opciones miden
/// exactamente lo mismo — evita el efecto "irregular" que se ve con
/// etiquetas largas (ej. "Jardín / Inicial (3 a 5 años)") al lado de otras
/// mucho más cortas.
///
/// Arma las filas a mano con `Row`/`Expanded` en vez de medir el ancho
/// disponible con `LayoutBuilder`: dentro de un `ExpansionTile`, que anima
/// su propia altura, las restricciones que le llegan a un `LayoutBuilder`
/// (o a un `Row` con `crossAxisAlignment.stretch`, que necesita una altura
/// ya definida) pueden quedar en un estado que rompe el cálculo — la
/// sección se ve vacía al desplegarla. `Expanded` sin `stretch` reparte el
/// ancho igual entre las dos tarjetas sin necesitar conocer ni el ancho ni
/// el alto de antemano, así que no tiene ese problema. La única
/// contrapartida es que, si una tarjeta ocupa dos líneas de texto y la de
/// al lado una sola, no quedan exactamente a la misma altura — un costo
/// menor comparado con romper la pantalla.
class GrillaDosColumnas extends StatelessWidget {
  const GrillaDosColumnas({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const espacio = 10.0;
    final filas = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (filas.isNotEmpty) filas.add(const SizedBox(height: espacio));
      final segundo = i + 1 < children.length ? children[i + 1] : null;
      filas.add(
        Row(
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: espacio),
            Expanded(child: segundo ?? const SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: filas);
  }
}
