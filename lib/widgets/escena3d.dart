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

/// Punto a [derecha] metros a la derecha de [c] mirando hacia [rumbo].
LatLng alLado(LatLng c, double rumbo, double derecha) =>
    mover(c, math.cos(rumbo) * derecha, -math.sin(rumbo) * derecha);

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

/// Color de techo/carrocería: la Ruta 1 gris se oscurece para que resalte sobre el mapa gris.
String colorFuerte(Ruta r) => r.id == 'R1' ? '#3a3a3c' : hexColor(r.color);

/// Caseta LZC simplificada (exagerada para verse desde arriba): banqueta, respaldo de cristal,
/// techo del color de la ruta y tótem con la pantalla amarilla del contador.
List<Map<String, dynamic>> caseta(Parada p, {bool resaltada = false}) {
  final r = p.ruta;
  final rumbo = r.trazo.rumboEn(p.metros);
  final c = p.punto;
  final ref = {'tipo': 'parada', 'ref': p.id};
  const lado = 18.0; // metros hacia la banqueta (a la derecha del sentido de la combi)
  final color = colorFuerte(r);
  return [
    caja(rectangulo(c, 30, 13, rumbo, derecha: lado), '#c7c7cc', 0, 1, ref),
    caja(rectangulo(c, 26, 1.8, rumbo, derecha: lado + 5.2), resaltada ? '#ffffff' : '#dbe7ef', 1, 10, ref),
    caja(rectangulo(c, 30, 12, rumbo, derecha: lado + 0.8), color, 10, 12, ref),
    caja(rectangulo(c, 2.4, 2.4, rumbo, adelante: 19, derecha: lado + 3), '#1c1c1e', 0, 17, ref),
    caja(rectangulo(c, 5.5, 2.8, rumbo, adelante: 19, derecha: lado + 3), resaltada ? '#34c759' : '#f2c200', 11, 17.5, ref),
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

/// Combi en 3D (exagerada): carrocería del color de la ruta, ventanas oscuras y techo blanco.
List<Map<String, dynamic>> combi3d(Ruta r, LatLng p, double rumbo, String ref, {bool resaltada = false, String? techo, double escala = 1}) {
  final props = {'tipo': 'combi', 'ref': ref};
  final color = colorFuerte(r);
  final k = (resaltada ? 2.6 : 2.1) * escala;
  return [
    caja(rectangulo(p, 16 * k, 7 * k, rumbo, derecha: 4), color, 0.6, 4.2 * k, props),
    caja(rectangulo(p, 12.5 * k, 7.2 * k, rumbo, adelante: -1.2 * k, derecha: 4), '#1f2a36', 4.2 * k, 6 * k, props),
    caja(rectangulo(p, 2.2 * k, 7.2 * k, rumbo, adelante: 6.2 * k, derecha: 4), '#1f2a36', 3.4 * k, 5.6 * k, props),
    caja(rectangulo(p, 15 * k, 6.6 * k, rumbo, adelante: -0.6 * k, derecha: 4), techo ?? (resaltada ? '#0a84ff' : '#ffffff'), 6 * k, 6.9 * k, props),
  ];
}

/// Color del techo según lo que hace la combi: verde = en parada (sube y baja gente),
/// rojo = en el semáforo, blanco = avanzando.
String? techoSegun(CombiEnRuta c) {
  if (!c.detenida) return null;
  final p = c.ruta.pausaEn(c.metros);
  if (p == null) return null;
  return p.parada != null ? '#34c759' : '#ff3b30';
}

String refCombi(CombiEnRuta c) => '${c.ruta.id}|${c.salida.round()}';

/// Punto de color con el número de la ruta: así se ve cada combi aunque el mapa esté lejos.
Map<String, dynamic> geoCombisPuntos(Iterable<Ruta> rs, double ahora, {Set<String> resaltadas = const {}}) => coleccion([
      for (final r in rs)
        for (final c in r.combisEn(ahora))
          punto(c.punto, {
            'color': hexColor(r.color),
            'texto': '${r.numero}',
            'letra': r.color.computeLuminance() > 0.5 ? '#111111' : '#ffffff',
            'radio': resaltadas.contains(refCombi(c)) ? 13.0 : 9.0,
            'tipo': 'combi',
            'ref': refCombi(c),
          }),
    ]);

Map<String, dynamic> geoParadasPuntos(Iterable<Ruta> rs) => coleccion([
      for (final r in rs)
        for (final p in r.paradas)
          if (p.principal) punto(p.punto, {'color': hexColor(r.color), 'tipo': 'parada', 'ref': p.id}),
    ]);

Map<String, dynamic> geoCombis(Iterable<Ruta> rs, double ahora, {Set<String> resaltadas = const {}}) {
  final f = <Map<String, dynamic>>[];
  for (final r in rs) {
    for (final c in r.combisEn(ahora)) {
      final ref = refCombi(c);
      f.addAll(combi3d(r, c.punto, r.trazo.rumboEn(c.metros), ref, resaltada: resaltadas.contains(ref), techo: techoSegun(c)));
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
        for (final t in o.enCombi) linea(t.puntos, {'color': colorFuerte(t.ruta!), 'ancho': 10.0, 'tipo': 'viaje'}),
    ]);

Map<String, dynamic> geoPie(Opcion? o) => coleccion([
      if (o != null)
        for (final t in o.tramos)
          if (t.tipo == TipoTramo.pie && t.segundos >= 30) linea(t.puntos, {'tipo': 'pie'}),
    ]);

/// Texto flotante sobre el mapa.
/// [prioridad]: las de número menor se colocan primero y no se tapan.
Map<String, dynamic> etiqueta(LatLng p, String texto, Color color, {int prioridad = 5}) =>
    punto(p, {'texto': texto, 'color': hexColor(color), 'prioridad': prioridad});


// ---------------- Vista de parada en 3D (escala real) ----------------

/// Caseta LZC a escala real (8 m × 3 m): banqueta, postes, techo, respaldo de cristal, banca,
/// tótem con pantalla del contador y letrero de la ruta.
List<Map<String, dynamic>> casetaReal(Parada p, {bool combiEnParada = false}) {
  final r = p.ruta;
  final rumbo = r.trazo.rumboEn(p.metros);
  final c = p.punto;
  const lado = 7.5; // de la línea de la ruta a la caseta
  final color = colorFuerte(r);
  final ref = {'tipo': 'parada', 'ref': p.id};
  Map<String, dynamic> b(double largo, double ancho, String col, double base, double alto, {double adelante = 0, double derecha = 0}) =>
      caja(rectangulo(c, largo, ancho, rumbo, adelante: adelante, derecha: lado + derecha), col, base, alto, ref);
  return [
    b(11, 5, '#c7c7cc', 0, 0.25), // banqueta
    b(11, 0.35, '#f2c200', 0, 0.27, derecha: -2.4), // guarnición amarilla
    for (final a in [-3.8, 3.8])
      for (final d in [-1.2, 1.3]) b(0.18, 0.18, '#3a3a3c', 0.25, 2.75, adelante: a, derecha: d), // postes
    b(8.6, 3.3, color, 2.75, 2.95), // techo
    b(8.2, 3.0, '#ffffff', 2.95, 3.0), // panel solar (borde)
    b(7.6, 2.6, '#1c3d5a', 2.96, 3.02), // panel solar
    b(7.4, 0.08, '#bcd9ea', 0.45, 2.5, derecha: 1.3), // respaldo de cristal
    b(4.8, 0.5, '#8e5a2b', 0.45, 0.55, derecha: 0.9), // banca
    for (final a in [-2.0, 2.0]) b(0.12, 0.4, '#3a3a3c', 0.25, 0.45, adelante: a, derecha: 0.9),
    b(0.4, 0.4, '#1c1c1e', 0.25, 2.9, adelante: 4.9, derecha: -0.6), // tótem
    b(0.9, 0.18, combiEnParada ? '#34c759' : '#f2c200', 1.6, 2.6, adelante: 4.9, derecha: -0.6), // pantalla
    b(0.9, 0.2, color, 2.9, 3.4, adelante: 4.9, derecha: -0.6), // letrero de la ruta
  ];
}

/// Combi a escala real (5.5 m × 2.1 m), con ventanas y techo que cambia de color al detenerse.
List<Map<String, dynamic>> combiReal(Ruta r, LatLng p, double rumbo, String ref, {String? techo, bool resaltada = false}) {
  final props = {'tipo': 'combi', 'ref': ref};
  final color = colorFuerte(r);
  Map<String, dynamic> b(double largo, double ancho, String col, double base, double alto, {double adelante = 0}) =>
      caja(rectangulo(p, largo, ancho, rumbo, adelante: adelante, derecha: 1.6), col, base, alto, props);
  return [
    for (final a in [-1.7, 1.7]) b(0.7, 2.2, '#1c1c1e', 0.0, 0.6, adelante: a), // llantas
    b(5.4, 2.0, color, 0.35, 1.3), // carrocería
    b(4.0, 2.04, '#1f2a36', 1.3, 2.0, adelante: -0.6), // ventanas
    b(0.9, 2.04, '#1f2a36', 1.2, 1.9, adelante: 2.1), // parabrisas
    b(4.6, 1.96, color, 2.0, 2.25, adelante: -0.3),
    b(4.2, 1.7, techo ?? (resaltada ? '#0a84ff' : '#ffffff'), 2.25, 2.4, adelante: -0.4), // techo
  ];
}
