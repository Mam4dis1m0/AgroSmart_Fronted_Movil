import 'package:flutter/material.dart';

/// Tokens de color del sistema de diseño AgroSmart (prototipo Figma Make).
///
/// Uso: importar en widgets y usar `AgroColors.primary`, `AgroColors.mint`, etc.
/// El tema Material (`agroTheme`) ya aplica estos valores a los componentes base.
class AgroColors {
  AgroColors._();

  /// Verde bosque muy oscuro: header superior, barra de navegación.
  static const forest = Color(0xFF0A2216);

  /// Texto casi negro sobre fondos claros.
  static const forestDeep = Color(0xFF0A140F);

  /// Verde oscuro primario: CTA principal, iconos activos.
  static const primary = Color(0xFF1B4332);

  /// Verde intermedio (hover / acentos).
  static const primaryLight = Color(0xFF2D6A4F);

  /// Verde claro secundario: fondos suaves, estados, acentos.
  static const mint = Color(0xFF74C69D);

  /// Verde menta pálido: textos de apoyo sobre fondo oscuro.
  static const mintPale = Color(0xFFA3E5BC);

  /// Fondo general de la app (verde pastel).
  static const surfaceGreen = Color(0xFFDDEAE0);

  /// Barra de navegación inferior.
  static const navBg = Color(0xFF0C1E14);
  static const navBorder = Color(0xFF1A3828);
  static const navInactive = Color(0xFF88A895);

  /// Ámbar: alertas neutras (stock bajo, pendiente de sincronización).
  static const amber = Color(0xFFE5A93C);

  /// Gris base / separación.
  static const grayBase = Color(0xFFF8F9FA);
  static const slateBorder = Color(0xFFE2E8F0);
  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const neutralBg = Color(0xFFF1F5F9);
  static const handle = Color(0xFFCBD5E1);

  /// Verdes del hero y del header.
  static const heroMid = Color(0xFF103221);
  static const heroEnd = Color(0xFF15432B);
  static const heroBorder = Color(0xFF214D36);
  static const forestTile = Color(0xFF143B26);
  static const forestTileBorder = Color(0xFF23583C);
  static const headerBorder = Color(0xFF163D27);
  static const mintSoft = Color(0xFF88D4A6);
  static const tabBorder = Color(0xFFC2D8C7);
  static const mintBorder = Color(0xFFA1C5AB);

  /// Semánticos: peligro / advertencia / información.
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerText = Color(0xFF991B1B);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFEF3C7);
  static const warningSoft = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);
  static const warningText = Color(0xFF78350F);
  static const info = Color(0xFF0369A1);
  static const infoBg = Color(0xFFE0F2FE);
  static const indigo = Color(0xFF4338CA);
  static const teal = Color(0xFF0F766E);
}

/// Estilos de texto reutilizables (la fuente incluida llega hasta peso 800).
class AgroText {
  AgroText._();
  static const title = TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark);
  static const muted = TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600, height: 1.35);
  static const amount = TextStyle(fontWeight: FontWeight.w800, color: AgroColors.primary);
}

/// Fuente del sistema de diseño.
const String kAgroFont = 'PlusJakartaSans';

/// Tema claro Material 3 con la identidad visual AgroSmart.
ThemeData buildAgroTheme() {
  const scheme = ColorScheme.light(
    primary: AgroColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AgroColors.primaryLight,
    onPrimaryContainer: Colors.white,
    secondary: AgroColors.mint,
    onSecondary: AgroColors.forestDeep,
    secondaryContainer: AgroColors.surfaceGreen,
    onSecondaryContainer: AgroColors.forest,
    tertiary: AgroColors.amber,
    onTertiary: AgroColors.forestDeep,
    surface: Colors.white,
    onSurface: AgroColors.textDark,
    surfaceContainerHighest: AgroColors.surfaceGreen,
    error: AgroColors.danger,
    onError: Colors.white,
    outline: AgroColors.slateBorder,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kAgroFont,
    scaffoldBackgroundColor: AgroColors.surfaceGreen,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = base.textTheme.apply(
    fontFamily: kAgroFont,
    bodyColor: AgroColors.textDark,
    displayColor: AgroColors.textDark,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AgroColors.primary,
        letterSpacing: -0.5,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 14, color: const Color(0xFF334155)),
      bodySmall: textTheme.bodySmall?.copyWith(fontSize: 12, color: AgroColors.textMuted),
      labelLarge: textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AgroColors.forest,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kAgroFont,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AgroColors.slateBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AgroColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontFamily: kAgroFont, fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AgroColors.primary,
        side: const BorderSide(color: AgroColors.primary, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontFamily: kAgroFont, fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AgroColors.primary,
        textStyle: const TextStyle(fontFamily: kAgroFont, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AgroColors.primary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(
        color: AgroColors.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      hintStyle: const TextStyle(color: AgroColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AgroColors.slateBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AgroColors.slateBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AgroColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AgroColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AgroColors.danger, width: 1.6),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AgroColors.slateBorder, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AgroColors.forest,
      contentTextStyle: const TextStyle(fontFamily: kAgroFont, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AgroColors.primary),
    listTileTheme: const ListTileThemeData(iconColor: AgroColors.primary),
    tabBarTheme: const TabBarThemeData(
      labelColor: AgroColors.forest,
      unselectedLabelColor: AgroColors.textMuted,
      labelStyle: TextStyle(fontFamily: kAgroFont, fontSize: 14, fontWeight: FontWeight.w800),
      unselectedLabelStyle: TextStyle(fontFamily: kAgroFont, fontSize: 14, fontWeight: FontWeight.w600),
      indicatorColor: AgroColors.forest,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AgroColors.primary,
      secondarySelectedColor: AgroColors.primary,
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(fontFamily: kAgroFont, fontWeight: FontWeight.w700, color: AgroColors.textDark),
      secondaryLabelStyle: const TextStyle(fontFamily: kAgroFont, fontWeight: FontWeight.w700, color: Colors.white),
      side: const BorderSide(color: AgroColors.slateBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontFamily: kAgroFont, color: AgroColors.textDark, fontWeight: FontWeight.w600),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AgroColors.primary : null),
    ),
    sliderTheme: const SliderThemeData(activeTrackColor: AgroColors.primary, thumbColor: AgroColors.primary),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontFamily: kAgroFont,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AgroColors.textDark,
      ),
    ),
  );
}
