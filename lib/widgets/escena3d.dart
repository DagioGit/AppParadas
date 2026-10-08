// Escena 3D del mapa principal: todo se dibuja como GeoJSON que MapLibre extruye
// (casetas, combis, semáforos, edificios) o pinta como líneas y textos.
//
// Las medidas están exageradas unas 2.5 veces para que se vean desde arriba.

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

import '../datos/semaforos.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';

String hexColor(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

List<double> lngLat(LatLng p) => [p.longitude, p.latitude];

Map<String, dynamic> coleccion(List<Map<String, dynamic>> f) => {'type': 'FeatureCollection', 'features': f};

/// Mueve [p] tantos metros al este y al norte.
LatLng mover(LatLng p, double este, double norte) => LatLng(
      p.latitude + norte / 110574,
      p.longitude + este / (111320 * math.cos(p.latitude * math.pi / 180)),
    );

/// Rectángulo de [largo] (en el sentido del [rumbo]) por [ancho], movido [adelante] y a la [derecha].
List<List<double>> rectangulo(LatLng c, double largo, double ancho, double rumbo, {double adelante = 0, double derecha = 0}) {
  final fx = math.sin(rumbo), fy = math.cos(rumbo); // hacia adelante (este, norte)
  final rx = fy, ry = -fx; // hacia la derecha
  final cx = fx * adelante + rx * derecha, cy = fy * adelante + ry * derecha;
  List<double> esquina(double a, double d) => lngLat(mover(c, cx + fx * a + rx * d, cy + fy * a + ry * d));
  final l = largo / 2, w = ancho / 2;
  final r = [esquina(l, w), esquina(l, -w), esquina(-l, -w), esquina(-l, w)];
  return [...r, r.first];
}

List<List<double>> circulo(LatLng c, double radio, {int lados = 10}) {
  final r = <List<double>>[];
  for (var i = 0; i <= lados; i++) {
    final a = 2 * math.pi * i / lados;
    r.add(lngLat(mover(c, radio * math.sin(a), radio * math.cos(a))));
  }
  return r;
}

Map<String, dynamic> caja(List<List<double>> anillo, String color, double base, double altura, [Map<String, dynamic>? extra]) => {
      'type': 'Feature',
      'properties': {'color': color, 'base': base, 'altura': altura, ...?extra},
      'geometry': {
        'type': 'Polygon',
        'coordinates': [anillo],
      },
    };

Map<String, dynamic> punto(LatLng p, Map<String, dynamic> props) => {
      'type': 'Feature',
      'properties': props,
      'geometry': {'type': 'Point', 'coordinates': lngLat(p)},
    };

Map<String, dynamic> linea(List<LatLng> pts, Map<String, dynamic> props) => {
      'type': 'Feature',
      'properties': props,
      'geometry': {'type': 'LineString', 'coordinates': [for (final p in pts) lngLat(p)]},
    };

// ---------------- Rutas ----------------

Map<String, dynamic> geoRutas(Iterable<Ruta> rs, {bool tenues = false}) => coleccion([
      for (final r in rs)
        linea(r.trazo.puntos, {
          'color': hexColor(r.color),
          'ancho': r.simulada ? 4.0 : 6.0,
          'opacidad': tenues ? 0.25 : (r.simulada ? 0.75 : 1.0),
          'tipo': 'ruta',
          'ref': r.id,
        }),
    ]);

// ---------------- Casetas (paradas en 3D) ----------------

/// Caseta LZC simplificada: banqueta, respaldo de cristal, techo del color de la ruta y tótem.
List<Map<String, dynamic>> caseta(Parada p, {bool resaltada = false}) {
  final r = p.ruta;
  final rumbo = r.trazo.rumboEn(p.metros);
  final c = p.punto;
  final ref = {'tipo': 'parada', 'ref': p.id};
  const lado = 11.0; // metros hacia la banqueta (a la derecha del sentido de la combi)
  final color = hexColor(r.color);
  return [
    caja(rectangulo(c, 18, 8, rumbo, derecha: lado), '#d1d1d6', 0, 0.6, ref),
    caja(rectangulo(c, 15, 1.2, rumbo, derecha: lado + 3.2), resaltada ? '#ffffff' : '#e8f0f5', 0.6, 6.5, ref),
    caja(rectangulo(c, 18, 7.5, rumbo, derecha: lado + 0.5), color, 6.5, 7.6, ref),
    caja(rectangulo(c, 1.6, 1.6, rumbo, adelante: 11.5, derecha: lado + 2), '#1c1c1e', 0, 10, ref),
    caja(rectangulo(c, 3.2, 1.8, rumbo, adelante: 11.5, derecha: lado + 2), resaltada ? '#34c759' : color, 7.5, 10.5, ref),
  ];
}

Map<String, dynamic> geoCasetas(Iterable<Ruta> rs, {Set<String> resaltadas = const {}}) => coleccion([
      for (final r in rs)
        for (final p in r.paradas)
          if (p.principal) ...caseta(p, resaltada: resaltadas.contains(p.id)),
    ]);

// ---------------- Semáforos ----------------

Map<String, dynamic> geoSemaforos() => coleccion([
      for (var i = 0; i < semaforos.length; i++) ...[
        caja(circulo(semaforos[i].punto, 0.9, lados: 8), '#1c1c1e', 0, 11, {'tipo': 'semaforo', 'ref': '$i'}),
        caja(rectangulo(semaforos[i].punto, 2.4, 2.4, 0), '#1c1c1e', 8, 15.5, {'tipo': 'semaforo', 'ref': '$i'}),
        caja(rectangulo(semaforos[i].punto, 2.8, 2.8, 0), '#ff453a', 13.6, 15, {'tipo': 'semaforo', 'ref': '$i'}),
        caja(rectangulo(semaforos[i].punto, 2.8, 2.8, 0), '#ffd60a', 11.6, 13, {'tipo': 'semaforo', 'ref': '$i'}),
        caja(rectangulo(semaforos[i].punto, 2.8, 2.8, 0), '#30d158', 9.6, 11, {'tipo': 'semaforo', 'ref': '$i'}),
      ],
    ]);

// ---------------- Combis ----------------

/// Combi en 3D: carrocería del color de la ruta, franja de ventanas oscura y techo blanco.
List<Map<String, dynamic>> combi3d(Ruta r, LatLng p, double rumbo, String ref, {bool resaltada = false}) {
  final props = {'tipo': 'combi', 'ref': ref};
  final color = hexColor(r.color);
  final k = resaltada ? 1.25 : 1.0;
  return [
    caja(rectangulo(p, 16 * k, 7 * k, rumbo, derecha: 2.5), color, 0.8, 4.2 * k, props),
    caja(rectangulo(p, 13 * k, 7.2 * k, rumbo, adelante: -1, derecha: 2.5), '#2c3e50', 4.2 * k, 6 * k, props),
    caja(rectangulo(p, 2.2 * k, 7.2 * k, rumbo, adelante: 6.2 * k, derecha: 2.5), '#2c3e50', 3.6 * k, 5.6 * k, props),
    caja(rectangulo(p, 15 * k, 6.6 * k, rumbo, adelante: -0.5, derecha: 2.5), resaltada ? '#ffffff' : color, 6 * k, 7 * k, props),
  ];
}

String refCombi(CombiEnRuta c) => '${c.ruta.id}|${c.salida.round()}';

Map<String, dynamic> geoCombis(Iterable<Ruta> rs, double ahora, {Set<String> resaltadas = const {}}) {
  final f = <Map<String, dynamic>>[];
  for (final r in rs) {
    for (final c in r.combisEn(ahora)) {
      final ref = refCombi(c);
      f.addAll(combi3d(r, c.punto, r.trazo.rumboEn(c.metros), ref, resaltada: resaltadas.contains(ref)));
    }
  }
  return coleccion(f);
}

// ---------------- Origen, destino y viaje ----------------

Map<String, dynamic> geoPines(LatLng origen, LatLng? destino) => coleccion([
      caja(circulo(origen, 4.5), '#0a84ff', 0, 16, {'tipo': 'origen'}),
      caja(circulo(origen, 7.5), '#ffffff', 16, 18, {'tipo': 'origen'}),
      if (destino != null) caja(circulo(destino, 4.5), '#ff3b30', 0, 22, {'tipo': 'destino'}),
      if (destino != null) caja(rectangulo(destino, 9, 1.2, math.pi / 2, adelante: 4.5), '#ff3b30', 15, 22, {'tipo': 'destino'}),
    ]);

Map<String, dynamic> geoViaje(Opcion? o) => coleccion([
      if (o != null)
        for (final t in o.tramos)
          if (t.tipo == TipoTramo.pie)
            linea(t.puntos, {'color': '#6e6e73', 'ancho': 4.0, 'tipo': 'viaje', 'pie': true})
          else
            linea(t.puntos, {'color': hexColor(t.ruta!.color), 'ancho': 10.0, 'tipo': 'viaje', 'pie': false}),
    ]);

/// Texto flotante sobre el mapa.
Map<String, dynamic> etiqueta(LatLng p, String texto, Color color, {double alto = 0}) =>
    punto(p, {'texto': texto, 'color': hexColor(color), 'alto': alto});
