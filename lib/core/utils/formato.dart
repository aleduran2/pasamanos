/// Formatea un precio con separador de miles estilo Argentina: `$ 5.000`.
/// Evitamos sumar el paquete `intl` solo para esto.
String formatearPrecio(double precio) {
  final entero = precio.round();
  final digitos = entero.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    final posicionDesdeElFinal = digitos.length - i;
    if (i > 0 && posicionDesdeElFinal % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digitos[i]);
  }
  return '\$ $buffer';
}

/// Fecha corta estilo Argentina: `24/09/2026`. Mismo motivo que arriba:
/// no vale la pena sumar `intl` para un formato tan simple.
String formatearFecha(DateTime fecha) {
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year}';
}
