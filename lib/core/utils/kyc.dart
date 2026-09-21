/// Monto a partir del cual un acuerdo requiere verificación de identidad
/// (decisión de negocio ya tomada: $20.000 ARS). Vive acá como constante
/// — no es un secreto, y tenerlo como valor de Dart (en vez de parsear el
/// .env en cada pantalla) hace más simple de testear el resto del flujo.
const double montoMinimoVerificacion = 20000;

bool requiereVerificacion(double precio) => precio >= montoMinimoVerificacion;
