/// Ciudades donde la app tiene actividad. El filtro de barrio/colegio
/// pregunta primero la ciudad y recién ofrece sus barrios/colegios — antes
/// era una sola lista larga que mezclaba Berisso y Ensenada (partidos
/// separados, no barrios de la ciudad de La Plata) con los barrios propios
/// de La Plata.
const List<String> ciudadesDisponibles = ['La Plata', 'Berisso', 'Ensenada'];

/// La inmensa mayoría de las publicaciones de hoy son de acá, así que
/// arranca preseleccionada y no le agrega un paso extra al caso común.
const String ciudadPorDefecto = 'La Plata';
