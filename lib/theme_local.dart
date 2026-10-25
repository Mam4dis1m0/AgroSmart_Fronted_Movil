import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta tomada de los diseños de Figma (login, market, AgroChat).
class C {
  static const verde = Color(0xFF2F6B4B);
  static const verdeMedio = Color(0xFF3B7F55);
  static const verdeOscuro = Color(0xFF123524);
  static const crema = Color(0xFFF6F9F2);
  static const salvia = Color(0xFFE8F0E6);
  static const borde = Color(0xFFDCE6D9);
  static const lima = Color(0xFFE6F36B);
  static const muted = Color(0xFF6B7F72);
  static const burbujaMia = Color(0xFFDDF3D6);
  static const ambar = Color(0xFFFFF0C2);
}

/// Títulos con tipografía serif (Fraunces), como en el diseño.
TextStyle serif(double size, {Color color = C.verdeOscuro, FontWeight w = FontWeight.w700, bool italic = false, double? h}) {
  return GoogleFonts.fraunces(
    fontSize: size,
    color: color,
    fontWeight: w,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: h,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: C.verde, surface: C.crema).copyWith(primary: C.verde);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: C.crema);
  return base.copyWith(
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(bodyColor: C.verdeOscuro, displayColor: C.verdeOscuro),
    appBarTheme: AppBarTheme(
      backgroundColor: C.crema,
      foregroundColor: C.verdeOscuro,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: serif(22),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.crema,
      indicatorColor: C.salvia,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: st.contains(WidgetState.selected) ? C.verdeOscuro : C.muted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.verde,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}

OutlineInputBorder _b(Color c, {double w = 1}) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c, width: w));

/// Campo de texto redondeado blanco, como en el login del diseño.
InputDecoration deco({String? hint, IconData? icon, Widget? suffix}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AAA9F)),
      prefixIcon: icon == null ? null : Icon(icon, color: C.muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: _b(C.borde),
      enabledBorder: _b(C.borde),
      focusedBorder: _b(C.verde, w: 1.6),
    );

/// Etiqueta pequeña en mayúsculas con espaciado (BIENVENIDO DE VUELTA, RECOMENDADOS…).
Widget eyebrow(String t, {Color color = C.muted}) =>
    Text(t.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 1.6, fontWeight: FontWeight.w600, color: color));

/// Logo cuadrado verde con brote.
class LogoBox extends StatelessWidget {
  final double size;
  const LogoBox({super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: C.verde, borderRadius: BorderRadius.circular(size * .3)),
        child: Icon(Icons.eco_outlined, color: Colors.white, size: size * .55),
      );
}
