import '../../features/catalogo/models/publicacion.dart';

/// Centinela para la opción "Otro" del selector de talle — para cargar una
/// medida en cm u otro valor que no esté en la lista fija (por ejemplo,
/// ropa de bebé que se mide en cm en vez de por edad).
const String talleOtroValor = '__otro_talle__';

/// Talles de ropa/uniformes de chicos, por edad (la forma más común de
/// hablar de talles de indumentaria infantil en Argentina). Se suman al
/// final los talles en letra (XS a XXL), habituales sobre todo en ropa
/// para adolescentes o en marcas que no usan el sistema por edad.
const List<String> tallesRopa = [
  '0-3 meses',
  '3-6 meses',
  '6-9 meses',
  '9-12 meses',
  '12-18 meses',
  '18-24 meses',
  '2 años',
  '4 años',
  '6 años',
  '8 años',
  '10 años',
  '12 años',
  '14 años',
  '16 años',
  'XS',
  'S',
  'M',
  'L',
  'XL',
  'XXL',
];

/// Numeración argentina de calzado infantil.
final List<String> tallesCalzado = [
  for (var numero = 16; numero <= 38; numero++) '$numero',
];

const List<String> colores = [
  'Blanco',
  'Negro',
  'Gris',
  'Celeste',
  'Azul',
  'Rojo',
  'Rosa',
  'Fucsia',
  'Verde',
  'Amarillo',
  'Naranja',
  'Violeta',
  'Marrón',
  'Beige',
  'Multicolor',
  'Estampado',
];

/// Qué lista de talles corresponde a cada categoría — `null` significa que
/// el talle no aplica (juguetes, libros, accesorios) y no hay que
/// mostrar ese filtro/campo para esa categoría.
List<String>? tallesParaCategoria(Categoria? categoria) {
  return switch (categoria) {
    Categoria.ropa || Categoria.uniformes => tallesRopa,
    Categoria.calzado => tallesCalzado,
    _ => null,
  };
}

/// Si tiene sentido filtrar/cargar color para esta categoría.
bool colorAplicaA(Categoria? categoria) {
  return switch (categoria) {
    Categoria.ropa ||
    Categoria.uniformes ||
    Categoria.calzado ||
    Categoria.accesorios ||
    Categoria.bebe => true,
    _ => false,
  };
}
