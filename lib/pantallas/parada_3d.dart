// "Ver parada en 3D": la caseta a escala real con sus edificios alrededor, las combis de la
// ruta llegando y deteniéndose en vivo, y la cuenta regresiva de la próxima.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../datos/semaforos.dart';
import '../modelo/geo.dart';
import '../modelo/ruta.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/escena3d.dart';
import '../widgets/mapa3d_base.dart';
import '../widgets/web/vista_web.dart';

/// Visor 3D de la página web (las mismas maquetas con árboles, edificios, gente y la combi).
const String urlVisor = 'https://dagiogit.github.io/rutas-lzc/visor.html';

/// "Ver parada en 3D": para la Ruta 1 y la Ruta 2 abre la maqueta de la página web;
/// para las rutas simuladas, una vista 3D sobre el mapa.
class Parada3D extends StatelessWidget {
  final Parada parada;
  const Parada3D({super.key, required this.parada});

  static String? urlPara(Parada p) {
    final r = p.ruta;
    final zona = r.id == 'R1' ? p.id : (r.id == 'R2' ? p.id.replaceFirst('R2-', '') : null);
    if (zona == null) return null;
    return Uri.parse(urlVisor).replace(queryParameters: {
      'zona': zona,
      'nombre': p.nombre,
      'lat': p.punto.latitude.toStringAsFixed(6),
      'lng': p.punto.longitude.toStringAsFixed(6),
      'f': '${r.frecuenciaMin}',
      'd': p.desfase.toStringAsFixed(0),
      'espera': esperaEnParada.toStringAsFixed(0),
    }).toString();
  }

  @override
  Widget build(BuildContext context) {
    final url = urlPara(parada);
    return url == null ? _Parada3DMapa(parada: parada) : _ParadaVisorWeb(parada: parada, url: url);
  }
}

class _ParadaVisorWeb extends StatelessWidget {
  final Parada parada;
  final String url;
  const _ParadaVisorWeb({required this.parada, required this.url});

  @override
  Widget build(BuildContext context) {
    final p = parada, r = parada.ruta;
    final arriba = MediaQuery.of(context).padding.top;
    final abajo = MediaQuery.of(context).padding.bottom;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFE6EEF3),
      child: Stack(children: [
        Positioned.fill(child: vistaWeb(url)),
        Positioned(
          left: 12,
          top: arriba + 8,
          right: 12,
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Tema.blanco, shape: BoxShape.circle, boxShadow: Tema.sombra),
                child: const Icon(CupertinoIcons.back, color: Tema.negro, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                decoration: BoxDecoration(color: Tema.blanco, borderRadius: BorderRadius.circular(21), boxShadow: Tema.sombra),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  InsigniaRuta(r, tam: 28),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tema.textoFijo(size: 16, weight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: abajo + 14,
          child: Center(
            child: ConReloj(
              cada: const Duration(seconds: 1),
              builder: (context, ahora) {
                final llegada = r.proximaLlegada(p, ahora);
                final falta = llegada - ahora;
                final enParada = r.combiEnParada(p, ahora);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xF0111111), borderRadius: BorderRadius.circular(24), boxShadow: Tema.sombra),
                  child: Text(
                    enParada
                        ? 'Combi en la parada'
                        : falta < 3600
                            ? 'Próxima combi en ${(falta / 60).floor()}:${(falta % 60).floor().toString().padLeft(2, '0')} · ${hora(llegada)}'
                            : 'Próxima combi a las ${hora(llegada)}',
                    style: Tema.textoFijo(size: 15, weight: FontWeight.w700, color: Tema.amarillo),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _Parada3DMapa extends StatefulWidget {
  final Parada parada;
  const _Parada3DMapa({required this.parada});

  @override
  State<_Parada3DMapa> createState() => _Parada3DState();
}

class _Parada3DState extends State<_Parada3DMapa> {
  ml.MapLibreMapController? _c;
  bool _listo = false;
  bool _ocupado = false;
  bool _girar = true;
  bool _seguir = false;
  double _rumbo = 0;
  Timer? _reloj;

  Parada get p => widget.parada;
  Ruta get r => p.ruta;

  /// Centro de la caseta (a un lado de la calle), para que la cámara gire alrededor de ella.
  LatLng get _centro => alLado(p.punto, r.trazo.rumboEn(p.metros), 6);

  @override
  void initState() {
    super.initState();
    _rumbo = r.trazo.rumboEn(p.metros) * 180 / math.pi + 70;
    _reloj = Timer.periodic(const Duration(milliseconds: 700), (_) => _tick());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  /// La combi que viene a esta parada (la próxima) y dónde va.
  (double llegada, LatLng? donde, double metrosFaltan) _proxima(double ahora) {
    final llegada = r.proximaLlegada(p, ahora);
    final pas = r.pasadaDe(p, llegada);
    final e = ahora - pas.salida;
    if (e < 0) return (llegada, null, p.metros);
    final m = pas.vuelta.metrosA(e);
    return (llegada, r.trazo.puntoEn(m), math.max(0.0, p.metros - m));
  }

  /// ¿Hay una combi detenida en esta parada ahora mismo?
  bool _enParada(double ahora) {
    for (final c in r.combisEn(ahora)) {
      if (c.detenida && (c.metros - p.metros).abs() < 1) return true;
    }
    return false;
  }

  void _tick() {
    if (!mounted || !_listo || _ocupado || !TickerMode.of(context)) return;
    _ocupado = true;
    _dibujar().whenComplete(() => _ocupado = false);
  }

  Future<void> _dibujar() async {
    final c = _c;
    if (c == null) return;
    final ahora = segundosAhora();
    final enParada = _enParada(ahora);
    // Combis de la ruta a menos de 2.5 km, a escala real
    final combis = <Map<String, dynamic>>[];
    for (final cb in r.combisEn(ahora)) {
      if (distanciaM(cb.punto, p.punto) > 2500) continue;
      combis.addAll(combiReal(r, cb.punto, r.trazo.rumboEn(cb.metros), refCombi(cb), techo: techoSegun(cb)));
    }
    final (llegada, donde, faltan) = _proxima(ahora);
    final etiquetas = <Map<String, dynamic>>[
      etiqueta(p.punto, enParada ? 'Combi en la parada' : 'Próxima combi ${_texto(llegada - ahora)}', enParada ? Tema.verdeFijo : Tema.negro, prioridad: 0),
      if (donde != null && !enParada)
        etiqueta(donde, 'Viene a ${(faltan / 1000).toStringAsFixed(1)} km', r.color.computeLuminance() > 0.6 ? const Color(0xFF8A6D00) : r.color, prioridad: 1),
    ];
    await c.setGeoJsonSource('casetas', coleccion(casetaReal(p, combiEnParada: enParada)));
    await c.setGeoJsonSource('combis', coleccion(combis));
    await c.setGeoJsonSource('etiquetas', coleccion(etiquetas));

    if (_seguir && donde != null) {
      await c.animateCamera(ml.CameraUpdate.newCameraPosition(ml.CameraPosition(
        target: ml.LatLng(donde.latitude, donde.longitude),
        zoom: 18.6,
        tilt: 62,
        bearing: r.trazo.rumboEn(p.metros - faltan) * 180 / math.pi,
      )));
    } else if (_girar) {
      _rumbo += 2.2;
      await c.animateCamera(
        ml.CameraUpdate.newCameraPosition(ml.CameraPosition(
          target: ml.LatLng(_centro.latitude, _centro.longitude),
          zoom: 20.2,
          tilt: 64,
          bearing: _rumbo,
        )),
        duration: const Duration(milliseconds: 700),
      );
    }
    if (mounted) setState(() {});
  }

  String _texto(double s) {
    if (s < 45) return 'llegando';
    if (s < 3600) return 'en ${(s / 60).floor()}:${(s % 60).floor().toString().padLeft(2, '0')}';
    return 'a las ${hora(s + segundosAhora())}';
  }

  @override
  Widget build(BuildContext context) {
    final ahora = segundosAhora();
    final llegadas = r.proximasLlegadas(p, ahora, n: 3);
    final enParada = _enParada(ahora);
    final arriba = MediaQuery.of(context).padding.top;
    final abajo = MediaQuery.of(context).padding.bottom;
    final semaforoCerca = semaforos.where((s) => distanciaM(s.punto, p.punto) < 250).toList();

    return CupertinoPageScaffold(
      child: Stack(children: [
        Positioned.fill(
          child: ml.MapLibreMap(
            styleString: estiloMapa3D,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(_centro.latitude, _centro.longitude),
              zoom: 20.2,
              tilt: 62,
              bearing: _rumbo,
            ),
            onMapCreated: (c) => _c = c,
            onStyleLoadedCallback: () async {
              final c = _c;
              if (c == null) return;
              await prepararEscena(c);
              await c.setGeoJsonSource('rutas', geoRutas([r]));
              await c.setGeoJsonSource('semaforos', geoSemaforos());
              _listo = true;
              await _dibujar();
            },
            compassEnabled: false,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
        ),
        // Barra superior
        Positioned(
          left: 12,
          right: 12,
          top: arriba + 8,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
            decoration: BoxDecoration(color: Tema.blanco, borderRadius: BorderRadius.circular(16), boxShadow: Tema.sombra),
            child: Row(children: [
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.back, color: Tema.azul),
              ),
              InsigniaRuta(r, tam: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tema.textoFijo(size: 17, weight: FontWeight.w700)),
                  Text('Caseta LZC · ${r.nombre} · ${p.sentido}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Tema.chicoFijo),
                ]),
              ),
            ]),
          ),
        ),
        // Tarjeta inferior con la cuenta regresiva
        Positioned(
          left: 12,
          right: 12,
          bottom: abajo + 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Tema.blanco, borderRadius: BorderRadius.circular(20), boxShadow: Tema.sombra),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: enParada ? Tema.verdeClaroFijo : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    enParada ? 'EN PARADA' : _texto(llegadas.first - ahora).toUpperCase(),
                    style: Tema.textoFijo(size: 22, weight: FontWeight.w800, color: enParada ? Tema.verdeFijo : Tema.amarillo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    enParada ? 'La combi está subiendo y bajando gente' : 'Próxima combi · ${hora(llegadas.first)}',
                    style: Tema.textoFijo(size: 15, weight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text('Después: ${llegadas.skip(1).map(hora).join(' · ')}', style: Tema.chicoFijo),
              if (semaforoCerca.isNotEmpty)
                Text('Cerca: ${semaforoCerca.first.nombre.toLowerCase()}', style: Tema.chicoFijo),
              Text('Techo verde = combi en parada · rojo = en semáforo', style: Tema.chicoFijo),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: _girar && !_seguir ? Tema.negro : Tema.fondoFijo,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () => setState(() {
                      _girar = !_girar || _seguir;
                      _seguir = false;
                    }),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.threesixty_rounded, size: 18, color: _girar && !_seguir ? const Color(0xFFFFFFFF) : Tema.negro),
                      const SizedBox(width: 6),
                      Text('Girar', style: Tema.textoFijo(size: 15, weight: FontWeight.w600, color: _girar && !_seguir ? const Color(0xFFFFFFFF) : Tema.negro)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: _seguir ? Tema.negro : Tema.fondoFijo,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () => setState(() => _seguir = !_seguir),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.directions_bus_rounded, size: 18, color: _seguir ? const Color(0xFFFFFFFF) : Tema.negro),
                      const SizedBox(width: 6),
                      Text('Seguir combi', style: Tema.textoFijo(size: 15, weight: FontWeight.w600, color: _seguir ? const Color(0xFFFFFFFF) : Tema.negro)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
