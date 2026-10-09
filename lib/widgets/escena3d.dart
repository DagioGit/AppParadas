// Escena 3D del mapa principal: todo se dibuja como GeoJSON que MapLibre extruye
// (casetas, combis, semáforos, edificios) o pinta como líneas y textos.
//
// Las medidas están exageradas unas 2.5 veces para que se vean desde arriba.

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

import '../datos/caseta_lzc.dart';
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

/// Punto del mapa en la posición ([x] a lo largo, [y] hacia la banqueta) de la caseta de [p].
LatLng puntoEnCaseta(Parada p, double x, double y, {double escala = 1, double lado = 5.2}) {
  final rumbo = p.ruta.trazo.rumboEn(p.metros);
  final adelante = mover(p.punto, math.sin(rumbo) * x * escala, math.cos(rumbo) * x * escala);
  return alLado(adelante, rumbo, lado + y * escala);
}

/// Color de techo/carrocería: la Ruta 1 gris se oscurece para que resalte sobre el mapa gris.
String colorFuerte(Ruta r) => r.id == 'R1' ? '#3a3a3c' : hexColor(r.color);

/// La Caseta LZC de la página web (mismo modelo de SketchUp), puesta junto a la parada.
/// [escala] 1 = tamaño real (4.9 m); en el mapa general se agranda para que se vea desde arriba.
/// La pantalla del contador cuelga del techo (verde cuando hay combi en la parada);
/// tiene banca adentro y afuera y botes de basura separada.
List<Map<String, dynamic>> casetaModelo(Parada p, {double escala = 1, double lado = 6.5, bool resaltada = false, bool combiEnParada = false}) {
  final r = p.ruta;
  final rumbo = r.trazo.rumboEn(p.metros);
  final c = p.punto;
  final ref = {'tipo': 'parada', 'ref': p.id};
  final minimo = escala > 1 ? 0.35 : 0.02; // piezas muy delgadas se engruesan si se agranda
  Map<String, dynamic> pieza(double x0, double x1, double y0, double y1, double z0, double z1, String color) {
    final largo = math.max((x1 - x0) * escala, minimo);
    final ancho = math.max((y1 - y0) * escala, minimo);
    return caja(
      rectangulo(c, largo, ancho, rumbo, adelante: (x0 + x1) / 2 * escala, derecha: lado + (y0 + y1) / 2 * escala),
      color,
      z0 * escala,
      z1 * escala,
      ref,
    );
  }

  return [
    for (final q in piezasCaseta)
      pieza(q.x0, q.x1, q.y0, q.y1, q.z0, q.z1, resaltada && q.nombre.startsWith('Tira_LED') ? '#34c759' : q.color),
    // Pantalla del contador colgada del techo, al frente: es parte de la caseta
    pieza(-1.18, -1.14, -0.96, -0.92, 2.2, 2.62, '#2b3237'),
    pieza(-0.36, -0.32, -0.96, -0.92, 2.2, 2.62, '#2b3237'),
    pieza(-1.32, -0.18, -1.0, -0.88, 1.9, 2.22, '#11181d'),
    pieza(-1.27, -0.23, -1.012, -0.998, 1.94, 2.18, combiEnParada || resaltada ? '#34c759' : '#f2c200'),
    // Tapas de los botes de basura separada y un tercero para reciclables
    pieza(2.48, 2.96, -0.09, 0.39, 0.85, 0.92, '#1f5f43'),
    pieza(2.48, 2.96, 0.38, 0.86, 0.85, 0.92, '#4a5157'),
    pieza(2.5, 2.94, -0.56, -0.12, 0.0, 0.85, '#1f5caa'),
    pieza(2.48, 2.96, -0.58, -0.1, 0.85, 0.92, '#163f78'),
    // Banca exterior de madera con patas de concreto, junto a la caseta
    pieza(-4.75, -4.6, 0.2, 0.7, 0.0, 0.42, '#a8a29a'),
    pieza(-3.4, -3.25, 0.2, 0.7, 0.0, 0.42, '#a8a29a'),
    pieza(-4.85, -3.15, 0.18, 0.72, 0.42, 0.48, '#9e683c'),
    pieza(-4.85, -3.15, 0.66, 0.74, 0.48, 0.92, '#9e683c'),
  ];
}

/// En el mapa general: la misma caseta, más grande para que se vea desde arriba.
List<Map<String, dynamic>> caseta(Parada p, {bool resaltada = false}) =>
    casetaModelo(p, escala: 3.2, lado: 16, resaltada: resaltada);

Map<String, dynamic> geoCasetas(Iterable<Ruta> rs, {Set<String> resaltadas = const {}}) => coleccion([
      for (final r in rs)
        for (final p in r.paradas)
          if (p.principal) ...caseta(p, resaltada: resaltadas.contains(p.id)),
    ]);

// ---------------- Semáforos ----------------

/// Semáforos como puntos: el mapa les pone el ícono 2D del semáforo.
Map<String, dynamic> geoSemaforos() => coleccion([
      for (var i = 0; i < semaforos.length; i++) punto(semaforos[i].punto, {'tipo': 'semaforo', 'ref': '$i'}),
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
  final p = c.pausa;
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

/// Caseta LZC a escala real (el modelo de la página web).
List<Map<String, dynamic>> casetaReal(Parada p, {bool combiEnParada = false}) =>
    casetaModelo(p, escala: 1, lado: 5.2, combiEnParada: combiEnParada);

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
