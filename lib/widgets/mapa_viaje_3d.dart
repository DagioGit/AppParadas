// Mapa 3D de la pestaña Viaje: las combis de cada opción avanzan en vivo y la parte de la
// ruta que ya recorrieron se va borrando. La opción elegida va resaltada; tocar su recorrido
// abre el paso a paso y tocar otra la elige.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../datos/lugares.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../tema.dart';
import 'escena3d.dart';
import 'hoja_parada.dart';
import 'mapa3d_base.dart';
import 'mapa_viaje.dart' show faltaTexto;

/// Dónde va (en metros sobre su ruta) la combi del tramo [t] en el segundo [ahora].
/// Devuelve null si ya terminó su vuelta.
double? metrosCombi(Tramo t, double ahora) {
  final r = t.ruta!;
  final salida = r.salidaDe(t.sube!, t.inicio);
  var e = ahora - salida;
  if (e <= 0) return 0;
  if (e > r.duracion) e -= r.duracion; // ya dio la vuelta (viajes que cruzan el inicio)
  if (e > r.duracion) return null;
  return r.metrosA(e);
}

/// Lo que a la combi le falta por recorrer: [acercándose a tu parada, tu viaje hasta bajarte].
List<List<LatLng>> pendiente(Tramo t, double ahora) {
  final r = t.ruta!;
  final sube = t.sube!, baja = t.baja!;
  if (ahora >= t.fin) return const [[], []];
  final m = metrosCombi(t, ahora) ?? sube.metros;
  final cruza = baja.metros < sube.metros; // el viaje pasa por el final del recorrido
  if (ahora < t.inicio) {
    final acercandose = m <= sube.metros ? r.trazo.tramo(m, sube.metros) : <LatLng>[];
    return [acercandose, r.tramoEntre(sube, baja)];
  }
  // Ya va arriba de la combi
  if (cruza && m < sube.metros && m > baja.metros) return [<LatLng>[], <LatLng>[]];
  if (!cruza && m >= baja.metros) return [<LatLng>[], <LatLng>[]];
  return [<LatLng>[], r.trazo.tramo(m, baja.metros)];
}

class MapaViaje3D extends StatefulWidget {
  final List<Opcion> opciones;
  final int seleccion;
  final Lugar? origen;
  final Lugar? destino;

  /// Toque en un lugar vacío del mapa (para marcar origen y destino con el dedo).
  final void Function(LatLng)? onTocarVacio;
  final void Function(int) onElegir;
  final void Function(Opcion) onDetalle;

  const MapaViaje3D({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.origen,
    required this.destino,
    this.onTocarVacio,
    required this.onElegir,
    required this.onDetalle,
  });

  @override
  State<MapaViaje3D> createState() => _MapaViaje3DState();
}

class _MapaViaje3DState extends State<MapaViaje3D> {
  ml.MapLibreMapController? _c;
  bool _listo = false;
  bool _ocupado = false;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted || !_listo || _ocupado || !TickerMode.of(context)) return;
      _ocupado = true;
      _vivo().whenComplete(() => _ocupado = false);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapaViaje3D viejo) {
    super.didUpdateWidget(viejo);
    final cambioPuntos = viejo.origen?.punto != widget.origen?.punto || viejo.destino?.punto != widget.destino?.punto;
    if (!identical(viejo.opciones, widget.opciones) || viejo.seleccion != widget.seleccion || cambioPuntos) {
      _todo();
      if (!identical(viejo.opciones, widget.opciones) && widget.opciones.isNotEmpty) _encuadrar();
    }
  }

  Opcion? get _elegida =>
      widget.opciones.isEmpty ? null : widget.opciones[widget.seleccion.clamp(0, widget.opciones.length - 1)];

  List<LatLng> get _puntos => [
        if (widget.origen != null) widget.origen!.punto,
        if (widget.destino != null) widget.destino!.punto,
        for (final o in widget.opciones)
          for (final t in o.tramos) ...t.puntos,
      ];

  ml.CameraPosition _camaraPara(List<LatLng> pts) {
    if (pts.length < 2) {
      final c = pts.isEmpty ? const LatLng(17.9600, -102.1990) : pts.first;
      return ml.CameraPosition(target: ml.LatLng(c.latitude - 0.004, c.longitude), zoom: 14.6, tilt: 45, bearing: -20);
    }
    var minLat = pts.first.latitude, maxLat = minLat, minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final lat = (minLat + maxLat) / 2;
    final alto = (maxLat - minLat) * 110574;
    final ancho = (maxLng - minLng) * 111320 * math.cos(lat * math.pi / 180);
    final tramo = math.max(math.max(alto, ancho) * 1.15, 350.0);
    final zoom = (math.log(78271.5 * math.cos(lat * math.pi / 180) * 390 / tramo) / math.ln2).clamp(12.5, 17.0);
    return ml.CameraPosition(
      target: ml.LatLng(lat - (maxLat - minLat) * 0.12, (minLng + maxLng) / 2),
      zoom: zoom.toDouble(),
      tilt: 50,
      bearing: -20,
    );
  }

  Future<void> _encuadrar() async {
    await _c?.animateCamera(ml.CameraUpdate.newCameraPosition(_camaraPara(_puntos)));
  }

  Future<void> _todo() async {
    final c = _c;
    if (c == null || !_listo) return;
    final sel = _elegida;
    final usadas = <String, Ruta>{
      for (final o in widget.opciones)
        for (final t in o.enCombi) t.ruta!.id: t.ruta!,
    };
    // Rutas completas muy tenues, para ubicarse
    final rutasTenues = geoRutas(usadas.values);
    for (final f in rutasTenues['features'] as List) {
      (f as Map)['properties']['opacidad'] = 0.18;
    }
    await c.setGeoJsonSource('rutas', rutasTenues);
    await c.setGeoJsonSource('casetas', coleccion([
      for (final o in widget.opciones)
        for (final t in o.enCombi) ...[
          ...caseta(t.sube!, resaltada: identical(o, sel)),
          ...caseta(t.baja!, resaltada: identical(o, sel)),
        ],
    ]));
    await c.setGeoJsonSource('pines', widget.origen == null
        ? coleccion([if (widget.destino != null) ...((geoPines(widget.destino!.punto, null)['features'] as List).cast<Map<String, dynamic>>())])
        : geoPines(widget.origen!.punto, widget.destino?.punto));
    await c.setGeoJsonSource('pie', coleccion([
      for (var i = 0; i < widget.opciones.length; i++)
        for (final t in widget.opciones[i].tramos)
          if (t.tipo == TipoTramo.pie && t.segundos >= 30)
            linea(t.puntos, {'tipo': 'pie', 'opcion': i, 'opacidad': i == widget.seleccion ? 1.0 : 0.3}),
    ]));
    await _vivo();
  }

  Future<void> _vivo() async {
    final c = _c;
    if (c == null || !_listo) return;
    final ahora = segundosAhora();
    final lineas = <Map<String, dynamic>>[];
    final combis = <Map<String, dynamic>>[];
    final puntos = <Map<String, dynamic>>[];
    final etiquetas = <Map<String, dynamic>>[];

    // Primero las otras opciones y al final la elegida, para que quede encima
    final orden = [
      for (var i = 0; i < widget.opciones.length; i++)
        if (i != widget.seleccion) i,
      if (widget.seleccion < widget.opciones.length) widget.seleccion,
    ];
    for (final i in orden) {
      final o = widget.opciones[i];
      final elegida = i == widget.seleccion;
      final tramos = o.enCombi.toList();
      for (var k = 0; k < tramos.length; k++) {
        final t = tramos[k];
        final r = t.ruta!;
        final color = colorFuerte(r);
        final partes = pendiente(t, ahora);
        if (partes[0].length > 1) {
          lineas.add(linea(partes[0], {'color': color, 'ancho': elegida ? 6.0 : 4.0, 'opacidad': elegida ? 0.55 : 0.25, 'tipo': 'viaje', 'opcion': i}));
        }
        if (partes[1].length > 1) {
          lineas.add(linea(partes[1], {'color': color, 'ancho': elegida ? 11.0 : 6.0, 'opacidad': elegida ? 1.0 : 0.4, 'tipo': 'viaje', 'opcion': i}));
        }
        final m = metrosCombi(t, ahora);
        if (m != null && ahora < t.fin) {
          final p = r.trazo.puntoEn(m);
          final ref = '$i|$k';
          final pausa = r.pausaEn(m);
          final techo = pausa == null ? null : (pausa.parada != null ? '#34c759' : '#ff3b30');
          combis.addAll([
            for (final f in combi3d(r, p, r.trazo.rumboEn(m), ref, resaltada: elegida, techo: techo))
              {...f, 'properties': {...(f['properties'] as Map<String, dynamic>), 'opcion': i}},
          ]);
          puntos.add(punto(p, {
            'color': hexColor(r.color),
            'texto': '${r.numero}',
            'letra': r.color.computeLuminance() > 0.5 ? '#111111' : '#ffffff',
            'radio': elegida ? 13.0 : 9.0,
            'tipo': 'combi',
            'opcion': i,
          }));
          final texto = ahora < t.inicio
              ? (ahora < r.salidaDe(t.sube!, t.inicio)
                  ? 'Ruta ${r.numero} · sale a las ${hora(r.salidaDe(t.sube!, t.inicio))}'
                  : 'Ruta ${r.numero} · a ${(((t.sube!.metros - m) % r.trazo.largo) / 1000).toStringAsFixed(1)} km · llega ${faltaTexto(t.inicio, ahora)}')
              : 'Vas en la Ruta ${r.numero} · bajas ${faltaTexto(t.fin, ahora)}';
          etiquetas.add(etiqueta(p, texto, elegida ? Tema.tinta : Tema.gris, prioridad: elegida ? 1 : 4));
        }
        if (elegida) {
          etiquetas.add(etiqueta(
            t.sube!.punto,
            k == 0 ? 'Sube aquí · ${faltaTexto(t.inicio, ahora)}' : 'Cambia a la Ruta ${r.numero} · ${faltaTexto(t.inicio, ahora)}',
            r.color.computeLuminance() > 0.6 ? const Color(0xFF8A6D00) : r.color,
            prioridad: 0,
          ));
          if (k == tramos.length - 1) {
            etiquetas.add(etiqueta(t.baja!.punto, 'Bájate aquí · ${hora(t.fin)}', Tema.tinta, prioridad: 2));
          }
        }
      }
    }
    if (widget.destino != null) etiquetas.add(etiqueta(widget.destino!.punto, widget.destino!.nombre, const Color(0xFFD70015), prioridad: 3));
    if (widget.origen != null) etiquetas.add(etiqueta(widget.origen!.punto, 'Sales de aquí', Tema.azul, prioridad: 3));

    await c.setGeoJsonSource('viaje', coleccion(lineas));
    await c.setGeoJsonSource('combis', coleccion(combis));
    await c.setGeoJsonSource('combis-puntos', coleccion(puntos));
    await c.setGeoJsonSource('etiquetas', coleccion(etiquetas));
  }

  Future<void> _alTocar(math.Point<double> punto, ml.LatLng donde) async {
    final c = _c;
    if (c == null) return;
    List<dynamic> f = const [];
    try {
      f = await c.queryRenderedFeatures(punto, ['combis-3d', 'combis-punto', 'viaje-linea', 'casetas-3d'], null);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    if (f.isEmpty) {
      widget.onTocarVacio?.call(LatLng(donde.latitude, donde.longitude));
      return;
    }
    final props = f.first is Map && (f.first as Map)['properties'] is Map ? (f.first as Map)['properties'] as Map : const {};
    if (props['tipo'] == 'parada') {
      final ref = '${props['ref']}';
      for (final r in rutas) {
        for (final p in r.paradas) {
          if (p.id == ref) {
            mostrarParada(context, p);
            return;
          }
        }
      }
      return;
    }
    final i = props['opcion'];
    final indice = i is num ? i.toInt() : int.tryParse('$i');
    if (indice == null || indice >= widget.opciones.length) return;
    if (indice == widget.seleccion) {
      widget.onDetalle(widget.opciones[indice]);
    } else {
      widget.onElegir(indice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ml.MapLibreMap(
      styleString: estiloMapa3D,
      initialCameraPosition: _camaraPara(_puntos),
      onMapCreated: (c) => _c = c,
      onStyleLoadedCallback: () async {
        final c = _c;
        if (c == null) return;
        await prepararEscena(c);
        _listo = true;
        await _todo();
      },
      onMapClick: _alTocar,
      compassEnabled: false,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
    );
  }
}
