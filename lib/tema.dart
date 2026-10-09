import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ajustes.dart';

/// Colores y letras de la app, al estilo de Ajustes de iPhone: fondo agrupado,
/// tarjetas redondeadas y modo claro u oscuro según los ajustes.
///
/// Los colores que cambian con el modo oscuro son getters. Los que terminan en
/// "Fijo" (y negro / blanco) no cambian: se usan sobre los mapas, que siempre son claros.
class Tema {
  /// Lo decide la app con los ajustes (Automática / Clara / Oscura).
  static bool oscuro = false;

  static bool get _c => ajustes.contraste;

  static Color get fondo => oscuro ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  static Color get tarjeta => oscuro ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  static Color get tinta => oscuro ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
  static Color get gris => oscuro
      ? (_c ? const Color(0xFFD1D1D6) : const Color(0xFF98989F))
      : (_c ? const Color(0xFF3A3A3C) : const Color(0xFF6E6E73));
  static Color get grisClaro => oscuro
      ? (_c ? const Color(0xFF8E8E93) : const Color(0xFF5A5A5F))
      : (_c ? const Color(0xFF6E6E73) : const Color(0xFFAEAEB2));
  static Color get linea => oscuro
      ? (_c ? const Color(0x66FFFFFF) : const Color(0x33FFFFFF))
      : (_c ? const Color(0x4D111111) : const Color(0x1F111111));
  static Color get relleno => oscuro ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  static Color get verde => oscuro ? const Color(0xFF30D158) : const Color(0xFF248A3D);
  static Color get verdeClaro => oscuro ? const Color(0xFF12301B) : const Color(0xFFE3F5E8);
  static Color get rojo => oscuro ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);

  static const amarillo = Color(0xFFF2C200);
  static const azul = Color(0xFF0A84FF);

  // Fijos (no cambian con el modo oscuro)
  static const negro = Color(0xFF111111);
  static const blanco = Color(0xFFFFFFFF);
  static const fondoFijo = Color(0xFFF2F2F7);
  static const grisFijo = Color(0xFF6E6E73);
  static const verdeFijo = Color(0xFF248A3D);
  static const verdeClaroFijo = Color(0xFFE3F5E8);

  /// En las pruebas automáticas no se descargan letras de internet.
  static bool usarFuenteWeb = true;

  /// Multiplica medidas de botones cuando "Botones grandes" está activado.
  static double b(double v) => ajustes.botonesGrandes ? v * 1.4 : v;

  static FontWeight _grueso(FontWeight w) {
    if (!ajustes.negritas) return w;
    final i = FontWeight.values.indexOf(w);
    if (i <= 3) return FontWeight.w600;
    if (i <= 5) return FontWeight.w700;
    return FontWeight.w800;
  }

  /// Letra de la app. Crece con el tamaño elegido en Ajustes (salvo [fijo]).
  static TextStyle texto({double size = 17, FontWeight weight = FontWeight.w400, Color? color, double? height, bool fijo = false}) {
    final s = fijo ? size : size * ajustes.letra;
    final w = _grueso(weight);
    final c = color ?? tinta;
    if (!usarFuenteWeb) {
      return TextStyle(fontSize: s, fontWeight: w, color: c, height: height, letterSpacing: -0.2);
    }
    return GoogleFonts.interTight(fontSize: s, fontWeight: w, color: c, height: height, letterSpacing: -0.2);
  }

  /// Letra sobre los mapas (siempre claros): negra por defecto.
  static TextStyle textoFijo({double size = 17, FontWeight weight = FontWeight.w400, Color color = negro, double? height}) =>
      texto(size: size, weight: weight, color: color, height: height);

  static TextStyle get titulo => texto(size: 22, weight: FontWeight.w700);
  static TextStyle get subtitulo => texto(size: 16, color: gris);
  static TextStyle get chico => texto(size: 14, color: gris);
  static TextStyle get chicoFijo => texto(size: 14, color: grisFijo);
  static TextStyle get etiqueta => texto(size: 13, weight: FontWeight.w600, color: gris);

  static List<BoxShadow> get sombra => [
        BoxShadow(color: oscuro ? const Color(0x66000000) : const Color(0x1A000000), blurRadius: 18, offset: const Offset(0, 6)),
      ];

  static CupertinoThemeData get cupertino => CupertinoThemeData(
        brightness: oscuro ? Brightness.dark : Brightness.light,
        primaryColor: azul,
        scaffoldBackgroundColor: fondo,
        barBackgroundColor: oscuro ? const Color(0xF0161618) : const Color(0xF0F9F9F9),
        textTheme: CupertinoTextThemeData(
          primaryColor: azul,
          textStyle: texto(),
          navTitleTextStyle: texto(size: 17, weight: FontWeight.w600, fijo: true),
          navLargeTitleTextStyle: texto(size: 34, weight: FontWeight.w800, fijo: true),
          tabLabelTextStyle: texto(size: 11, weight: FontWeight.w600, fijo: true),
          actionTextStyle: texto(color: azul),
        ),
      );
}
