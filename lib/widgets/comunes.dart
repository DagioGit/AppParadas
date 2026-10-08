import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../datos/semaforos.dart';
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
  final Color? borde;
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.onTap,
    this.color = Tema.tarjeta,
    this.borde,
  });

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: borde == null ? null : Border.all(color: borde!, width: 2),
      ),
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
      color: tenue ? color.withValues(alpha: 0.35) : color,
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

// ---------------- Combis animadas y semáforos ----------------

/// Reconstruye [builder] varias veces por segundo con la hora actual (segundos del día).
/// Usa un Ticker, así que se pausa sola cuando la pestaña no está visible.
class ConReloj extends StatefulWidget {
  final Widget Function(BuildContext context, double ahora) builder;
  final Duration cada;
  const ConReloj({super.key, required this.builder, this.cada = const Duration(milliseconds: 400)});

  @override
  State<ConReloj> createState() => _ConRelojState();
}

class _ConRelojState extends State<ConReloj> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _ultimo = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((transcurrido) {
      if (transcurrido - _ultimo >= widget.cada) {
        _ultimo = transcurrido;
        setState(() {});
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, segundosAhora());
}

/// Icono de una combi en el mapa, con el número de su ruta.
Widget iconoCombi(Ruta r, {double tam = 26, bool resaltada = false}) {
  final claro = r.color.computeLuminance() > 0.5;
  return Container(
    width: tam,
    height: tam,
    decoration: BoxDecoration(
      color: r.color,
      borderRadius: BorderRadius.circular(tam * 0.32),
      border: Border.all(color: const Color(0xFFFFFFFF), width: resaltada ? 3 : 2),
      boxShadow: [
        BoxShadow(color: resaltada ? r.color.withValues(alpha: 0.6) : const Color(0x55000000), blurRadius: resaltada ? 10 : 4, spreadRadius: resaltada ? 2 : 0),
      ],
    ),
    child: Icon(Icons.directions_bus_rounded, size: tam * 0.62, color: claro ? Tema.tinta : const Color(0xFFFFFFFF)),
  );
}

Marker marcadorCombi(CombiEnRuta c, {VoidCallback? onTap, double tam = 26}) => Marker(
      point: c.punto,
      width: tam + 6,
      height: tam + 6,
      child: GestureDetector(onTap: onTap, child: Center(child: iconoCombi(c.ruta, tam: tam))),
    );

/// Combis de varias rutas moviéndose sobre el mapa según su horario.
Widget capaCombis(Iterable<Ruta> rs, {void Function(CombiEnRuta)? onTap, double tam = 24}) {
  return ConReloj(builder: (context, ahora) {
    return MarkerLayer(markers: [
      for (final r in rs)
        for (final c in r.combisEn(ahora)) marcadorCombi(c, tam: tam, onTap: onTap == null ? null : () => onTap(c)),
    ]);
  });
}

/// Semáforo pequeño (caja negra con luz roja, amarilla y verde).
Widget iconoSemaforo({double alto = 30}) {
  Widget luz(Color c) => Container(
        width: alto * 0.22,
        height: alto * 0.22,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
  return Container(
    width: alto * 0.42,
    height: alto,
    padding: EdgeInsets.symmetric(vertical: alto * 0.07),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(alto * 0.14),
      border: Border.all(color: const Color(0xFFFFFFFF), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [luz(const Color(0xFFFF453A)), luz(const Color(0xFFFFD60A)), luz(const Color(0xFF30D158))],
    ),
  );
}

Marker marcadorSemaforo(Semaforo s, {VoidCallback? onTap, double alto = 28}) => Marker(
      point: s.punto,
      width: alto,
      height: alto + 4,
      child: GestureDetector(onTap: onTap, child: Center(child: iconoSemaforo(alto: alto))),
    );

/// Etiqueta tipo globo sobre el mapa ("Pasa aquí · 7 min", "Bájate aquí").
Marker marcadorEtiqueta(LatLng p, String texto, {Color color = Tema.tinta, Color letra = const Color(0xFFFFFFFF), VoidCallback? onTap, double ancho = 150}) => Marker(
      point: p,
      width: ancho,
      height: 64,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tema.texto(size: 12.5, weight: FontWeight.w700, color: letra)),
          ),
          CustomPaint(size: const Size(12, 7), painter: _Pico(color)),
        ]),
      ),
    );

class _Pico extends CustomPainter {
  final Color color;
  _Pico(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Pico old) => old.color != color;
}

/// Hoja pequeña con información de un semáforo.
Future<void> mostrarSemaforo(BuildContext context, Semaforo s) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(s.nombre, style: Tema.texto(size: 15, weight: FontWeight.w700)),
      message: Text('${s.detalle}.\nEn el horario simulado la combi se detiene en promedio ${esperaSemaforo.round()} s aquí.', style: Tema.texto(size: 13, color: Tema.gris)),
      cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
    ),
  );
}

/// Hoja pequeña con información de una combi en movimiento.
Future<void> mostrarCombi(BuildContext context, CombiEnRuta c) {
  final r = c.ruta;
  final sig = c.siguiente;
  final ahora = segundosAhora();
  final llega = sig == null ? null : sig.desfase - (ahora - c.salida);
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text('${r.nombre} · ${r.apodo}', style: Tema.texto(size: 15, weight: FontWeight.w700)),
      message: Text(
        'Salió a las ${hora(c.salida)}.'
        '${sig != null && llega != null ? '\nSiguiente parada: ${sig.nombre} (${llega < 45 ? 'llegando' : 'en ${(llega / 60).ceil()} min'}).' : ''}',
        style: Tema.texto(size: 13, color: Tema.gris),
      ),
      cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
    ),
  );
}

/// Panel inferior que se arrastra: hacia abajo deja ver el mapa, hacia arriba muestra todo.
/// Tocar la barrita de arriba lo encoge o lo vuelve a abrir. Se actualiza cada segundo.
class HojaDeslizable extends StatelessWidget {
  final DraggableScrollableController controlador;
  final List<Widget> Function(double ahora) hijos;
  final double inicial;
  final double minimo;
  final double maximo;
  const HojaDeslizable({
    super.key,
    required this.controlador,
    required this.hijos,
    this.inicial = 0.38,
    this.minimo = 0.17,
    this.maximo = 0.9,
  });

  void _alternar() {
    if (!controlador.isAttached) return;
    final abierta = controlador.size > minimo + 0.05;
    controlador.animateTo(abierta ? minimo : inicial, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      controller: controlador,
      initialChildSize: inicial,
      minChildSize: minimo,
      maxChildSize: maximo,
      snap: true,
      snapSizes: [inicial],
      builder: (context, sc) => Container(
        decoration: const BoxDecoration(
          color: Tema.fondo,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: ConReloj(
          cada: const Duration(seconds: 1),
          builder: (context, ahora) => ListView(
            controller: sc,
            padding: EdgeInsets.only(bottom: abajo + 16),
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _alternar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(color: Tema.grisClaro, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
              ...hijos(ahora),
            ],
          ),
        ),
      ),
    );
  }
}
