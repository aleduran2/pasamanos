import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño de Pasamanos.
///
/// Paleta profesional de marketplace: azul como color principal (transmite
/// confianza — el mismo rol que cumple el azul en la mayoría de los
/// marketplaces conocidos), con un acento cálido (coral) reservado para
/// detalles puntuales (favoritos, algunos íconos, el botón tonal de
/// "Cerrar acuerdo"), para no perder la calidez de una app entre familias
/// sin que el naranja domine toda la interfaz.
///
/// Partimos de `ColorScheme.fromSeed` para los roles seguros (error,
/// superficies, contornos, containers), pero definimos "primary" y
/// "secondary" a mano: el tono 40 que M3 deriva automáticamente de una
/// semilla queda siempre bastante apagado/grisáceo (verificado probando
/// varias semillas), así que en vez de heredarlo elegimos directamente los
/// colores finales y confirmamos el contraste con la fórmula de WCAG.
class AppTheme {
  AppTheme._();

  static const Color _semilla = Color(0xFF2557D6);

  static const Color _primario = Color(0xFF2557D6);
  static const Color _onPrimario = Color(0xFFFFFFFF);

  static const Color _secundario = Color(0xFFF4623A);
  static const Color _onSecundario = Color(0xFF2A1206);
  static const Color _secundarioContainer = Color(0xFFFFDAD2);
  static const Color _onSecundarioContainer = Color(0xFF723425);

  static ThemeData get light => _construir(
    _conMarcaPropia(ColorScheme.fromSeed(seedColor: _semilla)),
  );

  static ThemeData get dark => _construir(
    _conMarcaPropia(
      ColorScheme.fromSeed(seedColor: _semilla, brightness: Brightness.dark),
    ),
  );

  /// Mismo motivo que el comentario de arriba, pero acá importa aclarar
  /// que hay que aplicar esto en los DOS temas (claro y oscuro) por
  /// igual: quedó aplicado solo en el claro en una iteración anterior, y
  /// el resultado fue que en modo oscuro `primary`/`secondaryContainer`
  /// quedaban con el tono violeta que M3 deriva solo de la semilla —
  /// visible sobre todo en checkboxes y botones tonales, que usan esos
  /// roles como color de relleno.
  static ColorScheme _conMarcaPropia(ColorScheme base) {
    return base.copyWith(
      primary: _primario,
      onPrimary: _onPrimario,
      secondary: _secundario,
      onSecondary: _onSecundario,
      secondaryContainer: _secundarioContainer,
      onSecondaryContainer: _onSecundarioContainer,
    );
  }

  static ThemeData _construir(ColorScheme colorScheme) {
    final radioBase = BorderRadius.circular(16);
    final textTheme = GoogleFonts.nunitoTextTheme().apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Antes esto era un tinte casi invisible del mismo gris que las
        // tarjetas que envuelven al formulario (`_SeccionFormulario`), así
        // que el campo se perdía contra su fondo. Blanco/superficie base +
        // un borde visible siempre (no solo al enfocar) resuelve eso en
        // cualquier fondo donde caiga el campo.
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: radioBase,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radioBase,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radioBase,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radioBase,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radioBase,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radioBase),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radioBase),
          side: BorderSide(color: colorScheme.outline),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide.none,
        // Sin `labelStyle` a propósito: fijar acá un color (o incluso un
        // TextStyle sin color) pisa por completo el color adaptativo que
        // Material 3 calcula según el estado seleccionado/no seleccionado
        // del chip, y el texto puede terminar mezclándose con el fondo.
        // Cada chip de la app fija su propio color de texto a mano.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        extendedTextStyle: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
