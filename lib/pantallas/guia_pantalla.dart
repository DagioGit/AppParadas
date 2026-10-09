// Guía por voz en tiempo real: acompaña el viaje paso a paso y lo dice en voz alta.
// Caminar a la parada (con la distancia y hacia dónde), esperar la combi (cuánto falta),
// subirse, cuántas paradas faltan, cuándo bajarse y caminar al destino.
// Con GPS usa la posición real; sin GPS, avanza con el horario del viaje.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../modelo/geo.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../modelo/ubicacion.dart';
import '../tema.dart';
import '../voz.dart';
import '../widgets/comunes.dart';

class GuiaPantalla extends StatefulWidget {
  final Opcion opcion;
  final String destino;
  const GuiaPantalla({super.key, required this.opcion, required this.destino});

  @override
  State<GuiaPantalla> createState() => _GuiaPantallaState();
}

/// Hacia dónde queda [b] desde [a]: "hacia el norte", "hacia el sureste"…
String haciaDonde(LatLng a, LatLng b) {
  final dx = (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180);
  final dy = b.latitude - a.latitude;
  var ang = math.atan2(dx, dy) * 180 / math.pi;
  if (ang < 0) ang += 360;
  const nombres = ['norte', 'noreste', 'este', 'sureste', 'sur', 'suroeste', 'oeste', 'noroeste'];
  return 'hacia el ${nombres[((ang + 22.5) ~/ 45) % 8]}';
}

String metrosHablados(double m) {
  if (m < 20) return 'unos pasos';
  if (m < 1000) return '${(m / 10).round() * 10} metros';
  return '${(m / 1000).toStringAsFixed(1)} kilómetros';
}

class _GuiaPantallaState extends State<GuiaPantalla> {
  int _i = 0; // tramo actual
  LatLng? _pos; // GPS
  String? _sinGps;
  StreamSubscription<Position>? _gps;
  Timer? _reloj;
  final Set<String> _dichos = {};
  String _titulo = 'Empezamos';
  String _detalle = '';
  String _ultimo = '';
  bool _fin = false;

  List<Tramo> get _tramos => widget.opcion.tramos;

  @override
  void initState() {
    super.initState();
    _iniciarGps();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _paso());
    WidgetsBinding.instance.addPostFrameCallback((_) => _paso());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _gps?.cancel();
    Voz.callar();
    super.dispose();
  }

  Future<void> _iniciarGps() async {
    final r = await obtenerUbicacion();
    if (!mounted) return;
    if (r.punto == null || r.problema != null) {
      setState(() => _sinGps = 'Sin GPS: te guío con el horario del viaje.');
      return;
    }
    setState(() => _pos = r.punto);
    try {
      _gps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 4),
      ).listen((p) {
        if (mounted) setState(() => _pos = LatLng(p.latitude, p.longitude));
      });
    } catch (_) {}
  }

  /// Dice [texto] una sola vez por [clave].
  void _decir(String clave, String texto) {
    if (!_dichos.add(clave)) return;
    _ultimo = texto;
    Voz.decir(texto);
  }

  /// Dónde va la persona según el horario (cuando no hay GPS).
  LatLng _posEstimada(double ahora) {
    if (_i >= _tramos.length) return _tramos.last.hasta;
    final t = _tramos[_i];
    if (t.tipo == TipoTramo.combi) {
      if (ahora < t.inicio) return t.desde;
      final m = t.ruta!.metrosCombi(t.sube!, t.inicio, ahora);
      return m == null ? t.hasta : t.ruta!.trazo.puntoEn(m);
    }
    final u = ((ahora - t.inicio) / math.max(1, t.fin - t.inicio)).clamp(0.0, 1.0);
    return LatLng(t.desde.latitude + (t.hasta.latitude - t.desde.latitude) * u, t.desde.longitude + (t.hasta.longitude - t.desde.longitude) * u);
  }

  /// Paradas que faltan (contando la de bajada) para la combi del tramo [t] en el segundo [ahora].
  int _paradasQueFaltan(Tramo t, double ahora) {
    final r = t.ruta!;
    final pas = r.pasadaDe(t.sube!, t.inicio);
    final v = pas.vuelta;
    final e = ahora - pas.salida;
    final n = r.paradas.length;
    var faltan = 0;
    var i = t.sube!.indice;
    var vuelta = 0.0;
    while (i != t.baja!.indice) {
      i = (i + 1) % n;
      if (i == 0) vuelta = v.duracion;
      final llega = (vuelta == 0 ? v.llegadas[i] : vuelta + r.tipica.llegadas[i]);
      if (llega > e) faltan++;
    }
    return faltan;
  }

  void _paso() {
    if (!mounted || _fin) return;
    final ahora = segundosAhora();
    if (_i >= _tramos.length) {
      _terminar();
      return;
    }
    final t = _tramos[_i];
    final ultimo = _i == _tramos.length - 1;
    String titulo, detalle;

    if (t.tipo == TipoTramo.pie) {
      final aqui = _pos ?? _posEstimada(ahora);
      final dist = _pos != null ? distanciaM(_pos!, t.hasta) : math.max(0.0, t.metros * (t.fin - ahora) / math.max(1, t.fin - t.inicio));
      final llego = dist < 25 || (_pos == null && ahora >= t.fin);
      if (llego || t.segundos < 20) {
        if (ultimo) {
          _terminar();
          return;
        }
        final sig = _tramos[_i + 1];
        _decir('llego-$_i', 'Llegaste a la parada ${sig.sube!.nombre}. Espera la ${sig.ruta!.nombre}.');
        setState(() => _i++);
        return;
      }
      final hacia = haciaDonde(aqui, t.hasta);
      final meta = ultimo ? widget.destino : 'la parada ${t.hastaNombre}';
      titulo = 'Camina ${metrosHablados(dist)}';
      detalle = '$hacia, hasta $meta.';
      _decir('pie-$_i-${(dist / 100).ceil()}', 'Camina ${metrosHablados(dist)} $hacia, hasta $meta.');
    } else {
      final r = t.ruta!;
      final falta = t.inicio - ahora;
      if (falta > 25) {
        final min = (falta / 60).ceil();
        titulo = 'Tu combi llega en ${falta < 60 ? '${falta.round()} s' : '$min min'}';
        detalle = 'Espera la ${r.nombre} (${r.apodo}) en ${t.sube!.nombre}.';
        if (min <= 5 && [5, 3, 2, 1].contains(min)) {
          _decir('espera-$_i-$min', 'Tu combi, la ${r.nombre}, llega ${min == 1 ? 'en un minuto' : 'en $min minutos'}.');
        } else {
          _decir('espera-$_i', 'Espera la ${r.nombre} en ${t.sube!.nombre}. Llega ${cuandoHablado(t.inicio, ahora)}.');
        }
      } else if (ahora < t.inicio + 20) {
        titulo = '¡Súbete!';
        detalle = 'Llegó la ${r.nombre} (${r.apodo}). Bájate en ${t.baja!.nombre}.';
        _decir('ya-viene-$_i', 'Ya llegó tu combi: la ${r.nombre}, ${r.apodo}. Súbete. Te aviso dónde bajarte.');
      } else if (ahora < t.fin) {
        final faltan = _paradasQueFaltan(t, ahora);
        if (faltan <= 1) {
          titulo = 'Bájate en la próxima';
          detalle = 'Tu parada: ${t.baja!.nombre}. Pide la parada.';
          _decir('proxima-$_i', 'Prepárate: bájate en la próxima parada, ${t.baja!.nombre}. Pide la parada.');
        } else {
          titulo = 'Faltan $faltan paradas';
          detalle = 'Vas en la ${r.nombre}. Te bajas en ${t.baja!.nombre}.';
          _decir('bordo-$_i-$faltan', 'Vas en la combi. Faltan $faltan paradas para bajarte en ${t.baja!.nombre}.');
        }
      } else {
        _decir('baja-$_i', 'Bájate aquí: ${t.baja!.nombre}.');
        setState(() => _i++);
        return;
      }
    }
    setState(() {
      _titulo = titulo;
      _detalle = detalle;
    });
  }

  void _terminar() {
    _decir('fin', 'Llegaste a ${widget.destino}. Buen viaje.');
    setState(() {
      _fin = true;
      _titulo = '¡Llegaste!';
      _detalle = widget.destino;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ahora = segundosAhora();
    final aqui = _pos ?? _posEstimada(ahora);
    final o = widget.opcion;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Guía por voz')),
      child: SafeArea(
        child: Column(children: [
          // Indicación actual, grande
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(color: _fin ? Tema.verde : const Color(0xFF111111), borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                Icon(
                  _fin
                      ? Icons.flag_rounded
                      : (_i < _tramos.length && _tramos[_i].tipo == TipoTramo.combi ? Icons.directions_bus_rounded : Icons.directions_walk_rounded),
                  color: Tema.amarillo,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_titulo, style: Tema.texto(size: 28, weight: FontWeight.w800, color: const Color(0xFFFFFFFF))),
                    if (_detalle.isNotEmpty)
                      Text(_detalle, style: Tema.texto(size: 18, weight: FontWeight.w600, color: const Color(0xDDFFFFFF))),
                  ]),
                ),
              ]),
            ),
          ),
          if (_sinGps != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_sinGps!, style: Tema.chico),
            ),
          // Pasos del viaje
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (var k = 0; k < _tramos.length; k++)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: k == _i && !_fin ? Tema.azul : (k < _i || _fin ? Tema.verdeClaro : Tema.tarjeta),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        k < _i || _fin ? Icons.check_rounded : (_tramos[k].tipo == TipoTramo.pie ? Icons.directions_walk_rounded : Icons.directions_bus_rounded),
                        size: 20,
                        color: k == _i && !_fin ? const Color(0xFFFFFFFF) : Tema.tinta,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _tramos[k].tipo == TipoTramo.pie ? duracion(_tramos[k].segundos) : _tramos[k].ruta!.nombre,
                        style: Tema.texto(size: 15, weight: FontWeight.w700, color: k == _i && !_fin ? const Color(0xFFFFFFFF) : Tema.tinta),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          // Mapa del viaje
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Tema.fondoFijo),
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints([for (final t in o.tramos) ...t.puntos]),
                    padding: const EdgeInsets.all(36),
                  ),
                ),
                children: [
                  capaTeselas(),
                  PolylineLayer(polylines: [
                    for (final t in o.tramos)
                      t.tipo == TipoTramo.pie
                          ? Polyline(points: t.puntos, color: Tema.grisFijo, strokeWidth: 4, pattern: StrokePattern.dotted())
                          : lineaRuta(t.puntos, t.ruta!.color, ancho: 7),
                  ]),
                  capaTrafico(),
                  MarkerLayer(markers: [
                    marcadorDestino(o.tramos.last.hasta, tam: 42),
                    marcadorOrigen(aqui, tam: 30),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Repetir la indicación en voz alta',
                  child: CupertinoButton(
                    color: Tema.verde,
                    padding: EdgeInsets.symmetric(vertical: Tema.b(16)),
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () => Voz.decir(_ultimo.isEmpty ? '$_titulo. $_detalle' : _ultimo),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.volume_up_rounded, color: Color(0xFFFFFFFF), size: 26),
                      const SizedBox(width: 8),
                      Text('Repetir', style: Tema.texto(size: 19, weight: FontWeight.w800, color: const Color(0xFFFFFFFF))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  color: Tema.tarjeta,
                  padding: EdgeInsets.symmetric(vertical: Tema.b(16)),
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Terminar', style: Tema.texto(size: 19, weight: FontWeight.w800, color: Tema.rojo)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
