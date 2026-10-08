import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores y letras de la app (mismo lenguaje que la página web de Rutas LZC:
/// fondo gris claro, tinta casi negra, amarillo de la Ruta 2 y gris de la Ruta 1).
class Tema {
  static const fondo = Color(0xFFF2F2F7);
  static const tarjeta = Color(0xFFFFFFFF);
  static const tinta = Color(0xFF111111);
  static const gris = Color(0xFF6E6E73);
  static const grisClaro = Color(0xFFAEAEB2);
  static const linea = Color(0x1F111111);
  static const amarillo = Color(0xFFF2C200);
  static const verde = Color(0xFF248A3D);
  static const verdeClaro = Color(0xFFE3F5E8);
  static const azul = Color(0xFF0A84FF);

  /// En las pruebas automáticas no se descargan letras de internet.
  static bool usarFuenteWeb = true;

  static TextStyle texto({double size = 17, FontWeight weight = FontWeight.w400, Color color = tinta, double? height}) {
    if (!usarFuenteWeb) {
      return TextStyle(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: -0.2);
    }
    return GoogleFonts.interTight(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: -0.2);
  }

  static TextStyle get titulo => texto(size: 22, weight: FontWeight.w700);
  static TextStyle get subtitulo => texto(size: 15, color: gris);
  static TextStyle get chico => texto(size: 13, color: gris);
  static TextStyle get etiqueta => texto(size: 12, weight: FontWeight.w600, color: gris);

  static List<BoxShadow> get sombra => const [
        BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 6)),
      ];

  static CupertinoThemeData get cupertino => CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: tinta,
        scaffoldBackgroundColor: fondo,
        barBackgroundColor: const Color(0xF0F9F9F9),
        textTheme: CupertinoTextThemeData(
          primaryColor: tinta,
          textStyle: texto(),
          navTitleTextStyle: texto(size: 17, weight: FontWeight.w600),
          navLargeTitleTextStyle: texto(size: 34, weight: FontWeight.w800),
          tabLabelTextStyle: texto(size: 10, weight: FontWeight.w500),
          actionTextStyle: texto(color: azul),
        ),
      );
}
