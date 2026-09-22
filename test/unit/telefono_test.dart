import 'package:flutter_test/flutter_test.dart';
import 'package:pasamanos/core/utils/telefono.dart';

void main() {
  test('acepta el formato local típico', () {
    expect(esTelefonoValido('2211234567'), isTrue);
  });

  test('acepta separadores comunes (espacios, guiones, paréntesis, +)', () {
    expect(esTelefonoValido('221 123-4567'), isTrue);
    expect(esTelefonoValido('+54 9 221 123 4567'), isTrue);
    expect(esTelefonoValido('(221) 123-4567'), isTrue);
  });

  test('rechaza vacío', () {
    expect(esTelefonoValido(''), isFalse);
    expect(esTelefonoValido('   '), isFalse);
  });

  test('rechaza letras u otros caracteres no numéricos', () {
    expect(esTelefonoValido('221abc4567'), isFalse);
    expect(esTelefonoValido('llamame'), isFalse);
  });

  test('rechaza demasiado corto o demasiado largo', () {
    expect(esTelefonoValido('12345'), isFalse);
    expect(esTelefonoValido('12345678901234'), isFalse);
  });
}
