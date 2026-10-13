/// Colegios conocidos, agrupados por ciudad, para que las familias no
/// tengan que escribir el nombre a mano en el caso común. Si el colegio no
/// está en la lista de su ciudad, [SelectorConOtro] permite escribirlo
/// igual eligiendo "Otro".
const Map<String, List<String>> colegiosPorCiudad = {
  'La Plata': [
    'Bachillerato de Bellas Artes (UNLP)',
    'Colegio Del Pilar',
    'Colegio Del Prado (Gonnet)',
    'Colegio Del Sol',
    'Colegio Jesús Adolescente',
    'Colegio Los Robles (Gonnet)',
    'Colegio Manuel Belgrano',
    'Colegio María Auxiliadora',
    'Colegio Merceditas de San Martín',
    'Colegio Nacional Rafael Hernández (UNLP)',
    'Colegio Northlands',
    'Colegio San Luis',
    'Colegio San Marcos',
    'Colegio San Martín de Tours',
    'Colegio San Pedro Nolasco',
    'Colegio San Ramón No Nato',
    'Colegio San Vicente de Paul',
    'Colegio Santa Ana',
    'Colegio Santa Rita',
    'Colegio Santo Tomás de Aquino',
    'Escuela Graduada Joaquín V. González (UNLP)',
    'Escuela N.º 500',
    'Escuela Normal N.º 1',
    'Escuela Normal N.º 3',
    'Instituto Cristo Rey',
    'Instituto Iberoamericano',
    'Instituto Inmaculada Concepción',
    'Instituto La Salle La Plata',
    'Instituto San José La Plata',
    'Instituto San Juan Bosco (Villa Elisa)',
    'Instituto San Vicente de Paul (City Bell)',
    'Liceo Víctor Mercante (UNLP)',
  ],
  // Todavía sin curar: mientras tanto, elegir estas ciudades deja escribir
  // el colegio a mano vía "Otro".
  'Berisso': [],
  'Ensenada': [],
};

const String colegioOtroValor = '__otro__';

List<String> colegiosDe(String ciudad) =>
    colegiosPorCiudad[ciudad] ?? const [];
