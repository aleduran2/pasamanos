/// Barrios y localidades conocidas, agrupadas por ciudad, para que el
/// filtro de "Barrio" compare valores consistentes en vez de texto libre
/// (que nunca calza exacto entre lo que escribe quien publica y quien
/// busca) y, a la vez, no mezcle localidades de ciudades distintas en una
/// sola lista larga. Igual que con los colegios, "Otro" permite escribir
/// cualquier otro que no esté en la lista de su ciudad.
const Map<String, List<String>> barriosPorCiudad = {
  'La Plata': [
    'Abasto',
    'Altos de San Lorenzo',
    'Arturo Seguí',
    'Barrio Aeropuerto',
    'Barrio Norte',
    'Casco urbano (centro)',
    'City Bell',
    'Etcheverry',
    'Gonnet',
    'Gorina',
    'Hernández',
    'Los Hornos',
    'Melchor Romero',
    'Olmos',
    'Ringuelet',
    'San Carlos',
    'Tolosa',
    'Villa Castells',
    'Villa Elisa',
    'Villa Elvira',
  ],
  // Todavía sin curar: mientras tanto, elegir estas ciudades deja escribir
  // el barrio a mano vía "Otro".
  'Berisso': [],
  'Ensenada': [],
};

const String barrioOtroValor = '__otro_barrio__';

List<String> barriosDe(String ciudad) => barriosPorCiudad[ciudad] ?? const [];
