/// Valida que el texto tenga forma de número de WhatsApp argentino: se
/// permite escribirlo con espacios, guiones, paréntesis o el signo "+"
/// como separadores (se ignoran), pero lo que queda tiene que ser solo
/// dígitos y una cantidad de cifras razonable — cubre tanto el formato
/// local típico ("2211234567", 10 dígitos) como el internacional con
/// código de país ("5492211234567").
bool esTelefonoValido(String texto) {
  final soloDigitos = texto.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (soloDigitos.isEmpty) return false;
  if (!RegExp(r'^[0-9]+$').hasMatch(soloDigitos)) return false;
  return soloDigitos.length >= 8 && soloDigitos.length <= 13;
}

/// Mensaje de error a mostrar cuando [esTelefonoValido] da `false`.
const String mensajeTelefonoInvalido =
    'Ingresá un número válido (solo dígitos, sin letras).';
