// Mapa principal en 3D (MapLibre): edificios, casetas de las paradas, semáforos y combis
// moviéndose en vivo según su horario. Muestra cuánto le falta a la combi para llegar a
// la parada más cercana a ti y, si eliges a dónde vas, el viaje más rápido sobre el mapa.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../datos/lugares.dart';
import '../datos/semaforos.dart';
import '../estado.dart';
import '../modelo/geo.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../modelo/ubicacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/escena3d.dart';
import '../widgets/hoja_parada.dart';
import '../widgets/mapa_viaje.dart' show faltaTexto;
import 'buscar_lugar.dart';
import 'opcion_detalle.dart';
import 'viaje_pantalla.dart' show SecuenciaTramos;

const String estiloMapa = 'https://tiles.openfreemap.org/styles/positron';

/// Si no hay ubicación, se usa el Palacio Municipal como "estás aquí" (se cambia manteniendo presionado el mapa).
const LatLng origenDemo = LatLng(17.9622, -102.1987);

class MapaPantalla extends StatefulWidget {
  const MapaPantalla({super.key});

  @override
  State<MapaPantalla> createState() => _MapaPantallaState();
}

class _Cercana {
  final Parada parada;
  final double caminando; // segundos
  _Cercana(this.parada, this.caminando);
}

class _MapaPantallaState extends State<MapaPantalla> {
  ml.MapLibreMapController? _c;
  bool _listo = false;
  bool _tresD = true;
  Timer? _reloj;

  final Set<String> _visibles = {'R1', 'R2'};
  LatLng _yo = origenDemo;
  bool _yoReal = false;
  String? _aviso;

  Lugar? _destino;
  List<Opcion>? _opciones;
  int _sel = 0;

  Opcion? get _opcion => (_opciones == null || _opciones!.isEmpty) ? null : _opciones![_sel.clamp(0, _opciones!.length - 1)];

  Iterable<Ruta> get _rutasVisibles {
    final o = _opcion;
    if (o != null) {
      final ids = {for (final t in o.enCombi) t.ruta!.id};
      return rutas.where((r) => ids.contains(r.id));
    }
    return rutas.where((r) => _visibles.contains(r.id));
  }

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(milliseconds: 900), (_) => _cadaSegundo());
    _ubicarme(mover: false);
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  // ---------------- Datos ----------------

  /// La parada principal más cercana de cada ruta visible (a menos de 900 m).
  List<_Cercana> _cercanas() {
    final l = <_Cercana>[];
    for (final r in _rutasVisibles) {
      _Cercana? mejor;
      for (final p in r.paradas.where((p) => p.principal)) {
        final d = distanciaM(_yo, p.punto);
        if (d > 900) continue;
        final s = segundosAPie(_yo, p.punto);
        if (mejor == null || s < mejor.caminando) mejor = _Cercana(p, s);
      }
      if (mejor != null) l.add(mejor);
    }
    final ahora = segundosAhora();
    l.sort((a, b) => a.parada.ruta.proximaLlegada(a.parada, ahora).compareTo(b.parada.ruta.proximaLlegada(b.parada, ahora)));
    return l;
  }

  void _planear() {
    final d = _destino;
    if (d == null) {
      _opciones = null;
      return;
    }
    _opciones = Planificador().planear(_yo, d.punto,
        ahora: segundosAhora(), origenNombre: _yoReal ? 'Mi ubicación' : 'Tu punto', destinoNombre: d.nombre);
    _sel = 0;
  }

  // ---------------- Mapa ----------------

  Future<void> _alCargarEstilo() async {
    final c = _c;
    if (c == null) return;
    try {
      // Edificios en 3D con la altura de OpenStreetMap
      await c.addFillExtrusionLayer(
        'openmaptiles',
        'edificios-3d',
        ml.FillExtrusionLayerProperties(
          fillExtrusionColor: '#e3e3e8',
          fillExtrusionHeight: ['coalesce', ['get', 'render_height'], 6],
          fillExtrusionBase: ['coalesce', ['get', 'render_min_height'], 0],
          fillExtrusionOpacity: 0.85,
        ),
        sourceLayer: 'building',
        minzoom: 14,
        enableInteraction: false,
      );
    } catch (_) {
      // Si el estilo no trae edificios, el mapa sigue funcionando sin ellos.
    }
    await c.addGeoJsonSource('rutas', coleccion([]));
    await c.addGeoJsonSource('viaje', coleccion([]));
    await c.addGeoJsonSource('casetas', coleccion([]));
    await c.addGeoJsonSource('semaforos', geoSemaforos());
    await c.addGeoJsonSource('combis', coleccion([]));
    await c.addGeoJsonSource('pines', coleccion([]));
    await c.addGeoJsonSource('etiquetas', coleccion([]));

    await c.addLineLayer(
      'rutas',
      'rutas-borde',
      ml.LineLayerProperties(lineColor: '#ffffff', lineWidth: ['+', ['get', 'ancho'], 3], lineOpacity: ['get', 'opacidad'], lineJoin: 'round', lineCap: 'round'),
    );
    await c.addLineLayer(
      'rutas',
      'rutas-linea',
      ml.LineLayerProperties(lineColor: ['get', 'color'], lineWidth: ['get', 'ancho'], lineOpacity: ['get', 'opacidad'], lineJoin: 'round', lineCap: 'round'),
    );
    await c.addLineLayer(
      'viaje',
      'viaje-borde',
      ml.LineLayerProperties(lineColor: '#ffffff', lineWidth: ['+', ['get', 'ancho'], 4], lineJoin: 'round', lineCap: 'round'),
    );
    await c.addLineLayer(
      'viaje',
      'viaje-linea',
      ml.LineLayerProperties(lineColor: ['get', 'color'], lineWidth: ['get', 'ancho'], lineJoin: 'round', lineCap: 'round'),
    );
    final extrusion = ml.FillExtrusionLayerProperties(
      fillExtrusionColor: ['get', 'color'],
      fillExtrusionHeight: ['get', 'altura'],
      fillExtrusionBase: ['get', 'base'],
      fillExtrusionOpacity: 1.0,
    );
    await c.addFillExtrusionLayer('casetas', 'casetas-3d', extrusion);
    await c.addFillExtrusionLayer('semaforos', 'semaforos-3d', extrusion);
    await c.addFillExtrusionLayer('combis', 'combis-3d', extrusion);
    await c.addFillExtrusionLayer('pines', 'pines-3d', extrusion);
    await c.addSymbolLayer(
      'etiquetas',
      'etiquetas-texto',
      ml.SymbolLayerProperties(
        textField: ['get', 'texto'],
        textFont: ['Noto Sans Bold'],
        textSize: 14,
        textColor: ['get', 'color'],
        textHaloColor: '#ffffff',
        textHaloWidth: 2.5,
        textAnchor: 'bottom',
        textOffset: [0, -1.6],
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );
    _listo = true;
    final inicial = destinoMapaInicial;
    if (inicial != null) {
      destinoMapaInicial = null;
      setState(() {
        _destino = inicial;
        _planear();
      });
      await _dibujarTodo();
      final o = _opcion;
      await _encuadrar([_yo, inicial.punto, if (o != null) for (final t in o.tramos) ...t.puntos]);
      return;
    }
    await _dibujarTodo();
  }

  Future<void> _dibujarTodo() async {
    final c = _c;
    if (c == null || !_listo) return;
    final o = _opcion;
    final resaltadas = <String>{
      if (o != null)
        for (final t in o.enCombi) ...[t.sube!.id, t.baja!.id]
      else
        for (final x in _cercanas()) x.parada.id,
    };
    await c.setGeoJsonSource('rutas', geoRutas(_rutasVisibles, tenues: o != null));
    await c.setGeoJsonSource('viaje', geoViaje(o));
    await c.setGeoJsonSource('casetas', geoCasetas(_rutasVisibles, resaltadas: resaltadas));
    await c.setGeoJsonSource('pines', geoPines(_yo, _destino?.punto));
    await _dibujarVivo();
  }

  /// Combis y textos: se redibujan cada segundo.
  Future<void> _dibujarVivo() async {
    final c = _c;
    if (c == null || !_listo) return;
    final ahora = segundosAhora();
    final etiquetas = <Map<String, dynamic>>[];
    final destacadas = <String>{};

    final o = _opcion;
    if (o != null) {
      final combis = o.enCombi.toList();
      for (var i = 0; i < combis.length; i++) {
        final t = combis[i];
        final r = t.ruta!;
        etiquetas.add(etiqueta(
          t.sube!.punto,
          i == 0 ? 'Sube aquí · ${faltaTexto(t.inicio, ahora)}' : 'Cambia a la Ruta ${r.numero} · ${faltaTexto(t.inicio, ahora)}',
          r.color.computeLuminance() > 0.6 ? const Color(0xFF8A6D00) : r.color,
        ));
        final salida = r.salidaDe(t.sube!, t.inicio);
        destacadas.add('${r.id}|${salida.round()}');
        final p = r.combiQueLlega(t.sube!, t.inicio, ahora);
        if (p != null && ahora < t.inicio) etiquetas.add(etiqueta(p, 'Tu combi · ${faltaTexto(t.inicio, ahora)}', Tema.tinta));
      }
      if (combis.isNotEmpty) etiquetas.add(etiqueta(combis.last.baja!.punto, 'Bájate aquí · ${hora(combis.last.fin)}', Tema.tinta));
      if (_destino != null) etiquetas.add(etiqueta(_destino!.punto, _destino!.nombre, const Color(0xFFD70015)));
    } else {
      for (final x in _cercanas().take(3)) {
        final r = x.parada.ruta;
        final llegada = r.proximaLlegada(x.parada, ahora);
        etiquetas.add(etiqueta(x.parada.punto, 'Ruta ${r.numero} · ${faltaTexto(llegada, ahora)}',
            r.color.computeLuminance() > 0.6 ? const Color(0xFF8A6D00) : r.color));
        final salida = r.salidaDe(x.parada, llegada);
        destacadas.add('${r.id}|${salida.round()}');
        final p = r.combiQueLlega(x.parada, llegada, ahora);
        if (p != null) etiquetas.add(etiqueta(p, '→ tu parada ${faltaTexto(llegada, ahora)}', Tema.tinta));
      }
    }
    etiquetas.add(etiqueta(_yo, _yoReal ? 'Estás aquí' : 'Estás aquí (mantén presionado para mover)', Tema.azul));

    await c.setGeoJsonSource('combis', geoCombis(_rutasVisibles, ahora, resaltadas: destacadas));
    await c.setGeoJsonSource('etiquetas', coleccion(etiquetas));
  }

  bool _ocupado = false;
  void _cadaSegundo() {
    if (!mounted || !TickerMode.of(context)) return;
    if (_ocupado) return;
    _ocupado = true;
    _dibujarVivo().whenComplete(() => _ocupado = false);
    setState(() {}); // cuentas regresivas del panel
  }

  Future<void> _camara(LatLng centro, {double zoom = 15.6, double? tilt}) async {
    await _c?.animateCamera(ml.CameraUpdate.newCameraPosition(ml.CameraPosition(
      target: ml.LatLng(centro.latitude, centro.longitude),
      zoom: zoom,
      tilt: tilt ?? (_tresD ? 58 : 0),
      bearing: _tresD ? -28 : 0,
    )));
  }

  /// Encuadra varios puntos dejando lugar para el panel de abajo.
  Future<void> _encuadrar(List<LatLng> pts) async {
    if (pts.isEmpty) return;
    var minLat = pts.first.latitude, maxLat = minLat, minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final centro = LatLng((minLat + maxLat) / 2 - (maxLat - minLat) * 0.25, (minLng + maxLng) / 2);
    final alto = (maxLat - minLat) * 110574;
    final ancho = (maxLng - minLng) * 111320 * math.cos(centro.latitude * math.pi / 180);
    final tramo = math.max(math.max(alto, ancho) * 1.5, 400.0);
    final zoom = (math.log(78271.5 * math.cos(centro.latitude * math.pi / 180) * 360 / tramo) / math.ln2).clamp(12.5, 17.0);
    await _camara(centro, zoom: zoom.toDouble());
  }

  Future<void> _alTocarMapa(math.Point<double> punto, ml.LatLng _) async {
    final c = _c;
    if (c == null) return;
    List<dynamic> f = const [];
    try {
      f = await c.queryRenderedFeatures(punto, ['combis-3d', 'casetas-3d', 'semaforos-3d', 'viaje-linea'], null);
    } catch (_) {
      return;
    }
    if (f.isEmpty || !mounted) return;
    final props = _propiedades(f.first);
    final tipo = props['tipo'];
    final ref = '${props['ref'] ?? ''}';
    if (tipo == 'parada') {
      for (final r in rutas) {
        for (final p in r.paradas) {
          if (p.id == ref) {
            mostrarParada(context, p);
            return;
          }
        }
      }
    } else if (tipo == 'combi') {
      final ahora = segundosAhora();
      for (final r in rutas) {
        for (final cb in r.combisEn(ahora)) {
          if (refCombi(cb) == ref) {
            mostrarCombi(context, cb);
            return;
          }
        }
      }
    } else if (tipo == 'semaforo') {
      final i = int.tryParse(ref) ?? 0;
      mostrarSemaforo(context, semaforos[i.clamp(0, semaforos.length - 1)]);
    } else if (tipo == 'viaje' && _opcion != null) {
      _abrirDetalle(_opcion!);
    }
  }

  Map<String, dynamic> _propiedades(dynamic feature) {
    if (feature is Map) {
      final p = feature['properties'];
      if (p is Map) return p.map((k, v) => MapEntry('$k', v));
    }
    return const {};
  }

  // ---------------- Acciones ----------------

  Future<void> _ubicarme({bool mover = true}) async {
    final r = await obtenerUbicacion();
    if (!mounted) return;
    setState(() {
      if (r.punto != null && dentroDeLzc(r.punto!)) {
        _yo = r.punto!;
        _yoReal = true;
        _aviso = null;
      } else if (mover) {
        _aviso = r.problema ?? 'No se pudo obtener tu ubicación.';
      }
      _planear();
    });
    await _dibujarTodo();
    if (mover || _yoReal) await _camara(_yo, zoom: 16);
  }

  Future<void> _marcarAqui(LatLng p) async {
    setState(() {
      _yo = p;
      _yoReal = false;
      _aviso = null;
      _planear();
    });
    await _dibujarTodo();
  }

  Future<void> _buscarDestino() async {
    final l = await Navigator.of(context).push<Lugar>(CupertinoPageRoute(
      builder: (_) => const BuscarLugar(titulo: '¿A dónde vas?'),
    ));
    if (l == null || !mounted) return;
    if (l.tipo == TipoLugar.ubicacion) {
      // "Mi ubicación" como destino no tiene sentido: se usa como origen
      await _marcarAqui(l.punto);
      return;
    }
    setState(() {
      _destino = l;
      _planear();
    });
    await _dibujarTodo();
    final o = _opcion;
    await _encuadrar([_yo, l.punto, if (o != null) for (final t in o.tramos) ...t.puntos]);
  }

  Future<void> _quitarDestino() async {
    setState(() {
      _destino = null;
      _opciones = null;
    });
    await _dibujarTodo();
    await _camara(_yo);
  }

  Future<void> _elegirOpcion(int i) async {
    setState(() => _sel = i);
    await _dibujarTodo();
    final o = _opcion;
    if (o != null) await _encuadrar([for (final t in o.tramos) ...t.puntos]);
  }

  void _abrirDetalle(Opcion o) {
    Navigator.of(context).push(CupertinoPageRoute<void>(
      builder: (_) => OpcionDetalle(
        opcion: o,
        origen: Lugar(_yoReal ? 'Mi ubicación' : 'Tu punto', '', TipoLugar.ubicacion, _yo),
        destino: _destino!,
      ),
    ));
  }

  Future<void> _cambiarVista() async {
    setState(() => _tresD = !_tresD);
    final pos = _c?.cameraPosition;
    final t = pos?.target;
    await _camara(t == null ? _yo : LatLng(t.latitude, t.longitude), zoom: pos?.zoom ?? 15.6);
  }

  // ---------------- Pantalla ----------------

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.of(context).padding.top;
    final abajo = MediaQuery.of(context).padding.bottom;
    const altoPanel = 290.0;

    return CupertinoPageScaffold(
      child: Stack(children: [
        Positioned.fill(
          child: ml.MapLibreMap(
            styleString: estiloMapa,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(origenDemo.latitude - 0.002, origenDemo.longitude),
              zoom: 15.4,
              tilt: 58,
              bearing: -28,
            ),
            onMapCreated: (c) => _c = c,
            onStyleLoadedCallback: _alCargarEstilo,
            onMapClick: _alTocarMapa,
            onMapLongClick: (_, ll) => _marcarAqui(LatLng(ll.latitude, ll.longitude)),
            trackCameraPosition: true,
            compassEnabled: false,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
        ),
        // Buscador
        Positioned(
          left: 16,
          right: 16,
          top: arriba + 10,
          child: _destino == null ? _buscador() : _barraViaje(),
        ),
        // Filtros de rutas (sólo sin viaje)
        if (_destino == null)
          Positioned(
            left: 0,
            right: 0,
            top: arriba + 72,
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final r in rutas)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: PildoraRuta(
                        r,
                        activa: _visibles.contains(r.id),
                        onTap: () {
                          setState(() {
                            if (!_visibles.remove(r.id)) _visibles.add(r.id);
                          });
                          _dibujarTodo();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Botones
        Positioned(
          right: 16,
          bottom: abajo + altoPanel + 14,
          child: Column(children: [
            _BotonTexto(texto: _tresD ? '2D' : '3D', onTap: _cambiarVista),
            const SizedBox(height: 10),
            BotonFlotante(icono: Icons.near_me_rounded, onTap: () => _ubicarme()),
          ]),
        ),
        if (_aviso != null)
          Positioned(
            left: 16,
            right: 80,
            bottom: abajo + altoPanel + 14,
            child: GestureDetector(
              onTap: () => setState(() => _aviso = null),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xEE111111), borderRadius: BorderRadius.circular(14)),
                child: Text('${_aviso!} Mantén presionado el mapa para marcar dónde estás.',
                    style: Tema.texto(size: 14, color: const Color(0xFFFFFFFF))),
              ),
            ),
          ),
        // Panel inferior
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: altoPanel + abajo,
          child: Container(
            padding: EdgeInsets.only(bottom: abajo),
            decoration: const BoxDecoration(
              color: Tema.fondo,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: _destino == null ? _panelCerca() : _panelViaje(),
          ),
        ),
      ]),
    );
  }

  Widget _buscador() {
    return GestureDetector(
      onTap: _buscarDestino,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(16), boxShadow: Tema.sombra),
        child: Row(children: [
          const Icon(Icons.search_rounded, color: Tema.gris),
          const SizedBox(width: 10),
          Expanded(child: Text('¿A dónde vas?', style: Tema.texto(size: 18, weight: FontWeight.w600, color: Tema.gris))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: Tema.amarillo, borderRadius: BorderRadius.circular(8)),
            child: Text('LZC', style: Tema.texto(size: 13, weight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }

  Widget _barraViaje() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(16), boxShadow: Tema.sombra),
      child: Row(children: [
        const Icon(Icons.flag_rounded, color: Color(0xFFFF3B30), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: _buscarDestino,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Desde ${_yoReal ? 'tu ubicación' : 'el punto azul'}', style: Tema.chico),
              Text(_destino!.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tema.texto(size: 17, weight: FontWeight.w700)),
            ]),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: _quitarDestino,
          child: const Icon(Icons.close_rounded, color: Tema.gris),
        ),
      ]),
    );
  }

  Widget _asa() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 38,
          height: 5,
          decoration: BoxDecoration(color: Tema.grisClaro, borderRadius: BorderRadius.circular(3)),
        ),
      );

  /// Sin destino: las combis que van a pasar por las paradas más cercanas a ti.
  Widget _panelCerca() {
    final cercanas = _cercanas();
    final ahora = segundosAhora();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _asa(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
        child: Text('Combis cerca de ti', style: Tema.texto(size: 20, weight: FontWeight.w800)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Text(
          _yoReal ? 'Desde tu ubicación · en vivo' : 'Desde el punto azul · mantén presionado el mapa para moverlo',
          style: Tema.chico,
        ),
      ),
      Expanded(
        child: cercanas.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No hay paradas de las rutas encendidas a menos de 900 m. Prende otra ruta o mueve el punto azul.',
                    style: Tema.subtitulo),
              )
            : ListView(padding: const EdgeInsets.only(bottom: 8), children: [
                for (final x in cercanas) _filaCerca(x, ahora),
              ]),
      ),
    ]);
  }

  Widget _filaCerca(_Cercana x, double ahora) {
    final r = x.parada.ruta;
    final llegadas = r.proximasLlegadas(x.parada, ahora, n: 2);
    final falta = llegadas.first - ahora;
    final alcanzas = falta > x.caminando;
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: () => _camara(x.parada.punto, zoom: 17),
      child: Row(children: [
        InsigniaRuta(r, tam: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.parada.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tema.texto(size: 16, weight: FontWeight.w700)),
            Text(
              '${r.nombre} · ${duracion(x.caminando)} caminando'
              '${alcanzas ? '' : ' · mejor la siguiente (${hora(llegadas.last)})'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tema.chico,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(falta < 45 ? 'Llegando' : falta < 3600 ? '${(falta / 60).ceil()} min' : hora(llegadas.first),
              style: Tema.texto(size: 22, weight: FontWeight.w800, color: falta < 45 ? Tema.verde : Tema.tinta)),
          Text(hora(llegadas.first), style: Tema.chico),
        ]),
      ]),
    );
  }

  /// Con destino: las opciones de viaje; la elegida se dibuja en el mapa.
  Widget _panelViaje() {
    final ops = _opciones ?? const <Opcion>[];
    final ahora = segundosAhora();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _asa(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        child: Text(ops.isEmpty ? 'Sin combis para ese lugar' : '${ops.length} formas de llegar', style: Tema.texto(size: 20, weight: FontWeight.w800)),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.only(bottom: 8), children: [
          for (var i = 0; i < ops.length; i++) _tarjetaOpcion(ops[i], i, ahora),
        ]),
      ),
    ]);
  }

  Widget _tarjetaOpcion(Opcion o, int i, double ahora) {
    final elegida = i == _sel;
    final primera = o.enCombi.isEmpty ? null : o.enCombi.first;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => elegida ? _abrirDetalle(o) : _elegirOpcion(i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Tema.tarjeta,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: elegida ? Tema.tinta : const Color(0x00000000), width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(duracion(o.total), style: Tema.texto(size: 22, weight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('llegas ${hora(o.llegada)}', style: Tema.subtitulo),
            const Spacer(),
            if (o.masRapida)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Tema.verdeClaro, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded, size: 15, color: Tema.verde),
                  Text('Más rápida', style: Tema.texto(size: 12, weight: FontWeight.w700, color: Tema.verde)),
                ]),
              ),
          ]),
          const SizedBox(height: 6),
          SecuenciaTramos(opcion: o),
          if (primera != null) ...[
            const SizedBox(height: 6),
            Text(
              'La ${primera.ruta!.nombre} pasa por ${primera.sube!.nombre} ${faltaTexto(primera.inicio, ahora)}',
              style: Tema.texto(size: 14, weight: FontWeight.w600),
            ),
          ],
          if (elegida)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Toca otra vez para ver el paso a paso', style: Tema.texto(size: 12, color: Tema.azul)),
            ),
        ]),
      ),
    );
  }
}

class _BotonTexto extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  const _BotonTexto({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(14), boxShadow: Tema.sombra),
        child: Text(texto, style: Tema.texto(size: 16, weight: FontWeight.w800, color: Tema.azul)),
      ),
    );
  }
}
