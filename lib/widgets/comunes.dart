import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../modelo/ruta.dart';
import '../tema.dart';

/// Cuadrito con el número de la ruta en su color.
class InsigniaRuta extends StatelessWidget {
  final Ruta ruta;
  final double tam;
  const InsigniaRuta(this.ruta, {super.key, this.tam = 30});

  @override
  Widget build(BuildContext context) {
    final claro = ruta.color.computeLuminance() > 0.5;
    return Container(
      width: tam,
      height: tam,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ruta.color, borderRadius: BorderRadius.circular(tam * 0.28)),
      child: Text(
        '${ruta.numero}',
        style: Tema.texto(size: tam * 0.5, weight: FontWeight.w800, color: claro ? Tema.tinta : const Color(0xFFFFFFFF)),
      ),
    );
  }
}

/// Píldora "Ruta 1 · Malecón".
class PildoraRuta extends StatelessWidget {
  final Ruta ruta;
  final bool activa;
  final VoidCallback? onTap;
  const PildoraRuta(this.ruta, {super.key, this.activa = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
        decoration: BoxDecoration(
          color: activa ? Tema.tarjeta : const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: Tema.sombra,
        ),
        child: Opacity(
          opacity: activa ? 1 : 0.45,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            InsigniaRuta(ruta, tam: 24),
            const SizedBox(width: 7),
            Text(ruta.apodo, style: Tema.texto(size: 14, weight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// Tarjeta blanca redondeada, como las de iOS.
class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color color;
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.onTap,
    this.color = Tema.tarjeta,
  });

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
    if (onTap == null) return caja;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: caja);
  }
}

class Encabezado extends StatelessWidget {
  final String texto;
  const Encabezado(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 18, 32, 6),
      child: Text(texto.toUpperCase(), style: Tema.etiqueta),
    );
  }
}

// ---------------- Mapa ----------------

/// Mapa base de OpenStreetMap pasado a gris claro, para que las rutas de color resalten
/// (mismo estilo de "mapa gris" que la página web).
const ColorFilter _filtroGris = ColorFilter.matrix(<double>[
  0.2328, 0.6292, 0.0580, 0, 46, //
  0.1871, 0.6743, 0.0585, 0, 46, //
  0.1871, 0.6292, 0.1036, 0, 46, //
  0, 0, 0, 1, 0, //
]);

TileLayer capaTeselas() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'mx.lzc.app_paradas',
      maxNativeZoom: 19,
      maxZoom: 20,
      tileBuilder: (context, tileWidget, tile) => ColorFiltered(colorFilter: _filtroGris, child: tileWidget),
    );

Widget creditosMapa() => SimpleAttributionWidget(
      source: Text('© colaboradores de OpenStreetMap', style: Tema.texto(size: 11, color: Tema.gris)),
      backgroundColor: const Color(0xB3FFFFFF),
    );

Polyline lineaRuta(List<LatLng> puntos, Color color, {double ancho = 5, bool tenue = false}) => Polyline(
      points: puntos,
      color: tenue ? color.withOpacity(0.35) : color,
      strokeWidth: ancho,
      borderColor: tenue ? const Color(0x00FFFFFF) : const Color(0xFFFFFFFF),
      borderStrokeWidth: tenue ? 0 : 1.5,
    );

Polyline lineaPie(List<LatLng> puntos) => Polyline(
      points: puntos,
      color: Tema.gris,
      strokeWidth: 3,
    );

Marker marcadorParada(Parada p, {VoidCallback? onTap, double tam = 16}) => Marker(
      point: p.punto,
      width: tam + 14,
      height: tam + 14,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: tam,
            height: tam,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: p.ruta.color, width: tam * 0.25),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );

Marker marcadorPunto(LatLng p, {required Color color, IconData icono = Icons.circle, double tam = 30}) => Marker(
      point: p,
      width: tam,
      height: tam,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Icon(icono, size: tam * 0.5, color: const Color(0xFFFFFFFF)),
      ),
    );

Marker marcadorUbicacion(LatLng p) => Marker(
      point: p,
      width: 26,
      height: 26,
      child: Container(
        decoration: BoxDecoration(
          color: Tema.azul,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFFFFF), width: 4),
          boxShadow: const [BoxShadow(color: Color(0x550A84FF), blurRadius: 12, spreadRadius: 4)],
        ),
      ),
    );

/// Botón redondo flotante sobre el mapa.
class BotonFlotante extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  const BotonFlotante({super.key, required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(14), boxShadow: Tema.sombra),
        child: Icon(icono, color: Tema.azul, size: 22),
      ),
    );
  }
}
