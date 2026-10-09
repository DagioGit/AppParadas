// Guía por voz en tiempo real: acompaña el viaje paso a paso y lo dice en voz alta.
// Caminar a la parada (con la distancia y hacia dónde), esperar la combi (cuánto falta),
// subirse, cuántas paradas faltan, cuándo bajarse y caminar al destino.
// Con GPS usa la posición real; sin GPS, avanza con el horario del viaje.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../modelo/guia.dart';
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

class _GuiaPantallaState extends State<GuiaPantalla> {
  late final MotorGuia _motor = MotorGuia(widget.opcion, widget.destino);
  LatLng? _pos; // GPS
  String? _sinGps;
  StreamSubscription<Position>? _gps;
  Timer? _reloj;
  String _titulo = 'Empezamos';
  String _detalle = '';

  int get _i => _motor.i;
  bool get _fin => _motor.fin;
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

  void _paso() {
    if (!mounted) return;
    final e = _motor.paso(segundosAhora(), _pos);
    if (e.decir != null) Voz.decir(e.decir!);
    setState(() {
      _titulo = e.titulo;
      _detalle = e.detalle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ahora = segundosAhora();
    final aqui = _pos ?? _motor.posEstimada(ahora);
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
                    onPressed: () => Voz.decir(_motor.cuantoFalta(segundosAhora())),
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
