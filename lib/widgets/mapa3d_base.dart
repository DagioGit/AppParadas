// Capas comunes de los mapas 3D (MapLibre): edificios, rutas, viaje, casetas, semáforos,
// combis, pines y etiquetas. Cada pantalla sólo cambia los datos con setGeoJsonSource.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'escena3d.dart';

const String estiloMapa3D = 'https://tiles.openfreemap.org/styles/positron';

Future<void> prepararEscena(ml.MapLibreMapController c) async {
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
  await c.addGeoJsonSource('pie', coleccion([]));
  await c.addGeoJsonSource('casetas', coleccion([]));
  await c.addGeoJsonSource('semaforos', geoSemaforos());
  await c.addGeoJsonSource('combis', coleccion([]));
  await c.addGeoJsonSource('combis-puntos', coleccion([]));
  await c.addGeoJsonSource('paradas-puntos', coleccion([]));
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
    ml.LineLayerProperties(lineColor: '#ffffff', lineWidth: ['+', ['get', 'ancho'], 4], lineOpacity: ['coalesce', ['get', 'opacidad'], 1], lineJoin: 'round', lineCap: 'round'),
  );
  await c.addLineLayer(
    'viaje',
    'viaje-linea',
    ml.LineLayerProperties(lineColor: ['get', 'color'], lineWidth: ['get', 'ancho'], lineOpacity: ['coalesce', ['get', 'opacidad'], 1], lineJoin: 'round', lineCap: 'round'),
  );
  // Flechas sobre los recorridos del viaje: hacia dónde va la combi
  await c.addSymbolLayer(
    'viaje',
    'viaje-flechas',
    ml.SymbolLayerProperties(
      symbolPlacement: 'line',
      symbolSpacing: 70,
      textField: '›',
      textFont: ['Noto Sans Bold'],
      textSize: 22,
      textColor: '#ffffff',
      textOpacity: ['coalesce', ['get', 'opacidad'], 1],
      textKeepUpright: false,
      textAllowOverlap: true,
      textIgnorePlacement: true,
    ),
  );
  // Caminatas: línea punteada gris
  await c.addLineLayer(
    'pie',
    'pie-linea',
    ml.LineLayerProperties(lineColor: '#6e6e73', lineWidth: 4, lineDasharray: [1, 1.6], lineCap: 'round', lineOpacity: ['coalesce', ['get', 'opacidad'], 1]),
  );
  final extrusion = ml.FillExtrusionLayerProperties(
    fillExtrusionColor: ['get', 'color'],
    fillExtrusionHeight: ['get', 'altura'],
    fillExtrusionBase: ['get', 'base'],
    fillExtrusionOpacity: 1.0,
  );
  await c.addFillExtrusionLayer('casetas', 'casetas-3d', extrusion);
  // Semáforos: ícono 2D (siempre de frente a la cámara)
  try {
    await c.addImage('semaforo', await iconoSemaforoPng());
  } catch (_) {}
  await c.addSymbolLayer(
    'semaforos',
    'semaforos-3d',
    ml.SymbolLayerProperties(
      iconImage: 'semaforo',
      iconSize: 0.5,
      iconAnchor: 'bottom',
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
    ),
  );
  await c.addFillExtrusionLayer('combis', 'combis-3d', extrusion);

  await c.addCircleLayer(
    'paradas-puntos',
    'paradas-punto',
    ml.CircleLayerProperties(circleRadius: 5, circleColor: '#ffffff', circleStrokeColor: ['get', 'color'], circleStrokeWidth: 3),
    maxzoom: 15.6,
  );
  await c.addCircleLayer(
    'combis-puntos',
    'combis-punto',
    ml.CircleLayerProperties(circleRadius: ['get', 'radio'], circleColor: ['get', 'color'], circleStrokeColor: '#ffffff', circleStrokeWidth: 2.5),
    maxzoom: 16.2,
  );
  // Dónde estás y a dónde vas: íconos 2D (círculo con la flecha de Viaje y pin)
  try {
    await c.addImage('origen', await iconoOrigenPng());
    await c.addImage('destino', await iconoDestinoPng());
  } catch (_) {}
  await c.addSymbolLayer(
    'pines',
    'pines-2d',
    ml.SymbolLayerProperties(
      iconImage: ['get', 'icono'],
      iconSize: 0.5,
      iconAnchor: ['match', ['get', 'tipo'], 'destino', 'bottom', 'center'],
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
    ),
  );
  await c.addSymbolLayer(
    'combis-puntos',
    'combis-numero',
    ml.SymbolLayerProperties(
      textField: ['get', 'texto'],
      textFont: ['Noto Sans Bold'],
      textSize: 11,
      textColor: ['get', 'letra'],
      textAllowOverlap: true,
      textIgnorePlacement: true,
    ),
    maxzoom: 16.2,
  );
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
      textOffset: ['coalesce', ['get', 'offset'], ['literal', [0, -1.6]]],
      textAllowOverlap: false,
      textIgnorePlacement: false,
      symbolSortKey: ['get', 'prioridad'],
      textMaxWidth: 14,
    ),
  );
}

Future<Uint8List> _png(ui.Picture p, int w, int h) async {
  final img = await p.toImage(w, h);
  final datos = await img.toByteData(format: ui.ImageByteFormat.png);
  return datos!.buffer.asUint8List();
}

/// Flecha de Viaje (la de la pestaña) dentro de un cuadro de 24 × 24, escalada a [s] y movida a [o].
ui.Path flechaViaje(double s, ui.Offset o) {
  final k = s / 24;
  ui.Offset q(double x, double y) => ui.Offset(o.dx + x * k, o.dy + y * k);
  final a = q(21, 3), b = q(3, 10.5), c = q(10.3, 13.7), d = q(13.5, 21);
  return ui.Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..lineTo(d.dx, d.dy)
    ..close();
}

/// Dónde estás: círculo azul con borde blanco y la flecha de Viaje (96 px, se dibuja a la mitad).
Future<Uint8List> iconoOrigenPng() async {
  const t = 96.0;
  final g = ui.PictureRecorder();
  final c = ui.Canvas(g);
  c.drawCircle(const ui.Offset(t / 2, t / 2 + 2), 42, ui.Paint()..color = const ui.Color(0x40000000));
  c.drawCircle(const ui.Offset(t / 2, t / 2), 42, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  c.drawCircle(const ui.Offset(t / 2, t / 2), 35, ui.Paint()..color = const ui.Color(0xFF0A84FF));
  c.drawPath(flechaViaje(44, const ui.Offset(t / 2 - 23, t / 2 - 21)), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  return _png(g.endRecording(), t.toInt(), t.toInt());
}

/// A dónde vas: pin de ubicación rojo con borde blanco y punto blanco (la punta abajo).
Future<Uint8List> iconoDestinoPng() async {
  const w = 80.0, h = 108.0;
  final g = ui.PictureRecorder();
  final c = ui.Canvas(g);
  ui.Path pin(double r, double cy, double punta) {
    const cx = w / 2;
    return ui.Path()
      ..moveTo(cx, punta)
      ..cubicTo(cx - r * 0.55, punta - r * 1.0, cx - r, cy + r * 0.55, cx - r, cy)
      ..arcToPoint(ui.Offset(cx + r, cy), radius: ui.Radius.circular(r))
      ..cubicTo(cx + r, cy + r * 0.55, cx + r * 0.55, punta - r * 1.0, cx, punta)
      ..close();
  }

  c.drawPath(pin(34, 38, h - 2).shift(const ui.Offset(0, 2)), ui.Paint()..color = const ui.Color(0x40000000));
  c.drawPath(pin(34, 38, h - 4), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  c.drawPath(pin(28, 38, h - 14), ui.Paint()..color = const ui.Color(0xFFFF3B30));
  c.drawCircle(const ui.Offset(w / 2, 38), 11, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  return _png(g.endRecording(), w.toInt(), h.toInt());
}

/// Dibuja el ícono del semáforo (caja negra con luz roja, amarilla y verde y su poste) como PNG.
Future<Uint8List> iconoSemaforoPng() async {
  const w = 44.0, h = 104.0;
  final grabadora = ui.PictureRecorder();
  final c = ui.Canvas(grabadora);
  final negro = ui.Paint()..color = const ui.Color(0xFF1C1C1E);
  final blanco = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  // poste
  c.drawRect(const ui.Rect.fromLTWH(w / 2 - 3, 66, 6, 38), negro);
  // caja con borde blanco
  c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(2, 2, w - 4, 66), const ui.Radius.circular(9)), blanco);
  c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(5, 5, w - 10, 60), const ui.Radius.circular(7)), negro);
  const luces = [ui.Color(0xFFFF453A), ui.Color(0xFFFFD60A), ui.Color(0xFF30D158)];
  for (var i = 0; i < 3; i++) {
    c.drawCircle(ui.Offset(w / 2, 16 + i * 19.0), 7.5, ui.Paint()..color = luces[i]);
  }
  final img = await grabadora.endRecording().toImage(w.toInt(), h.toInt());
  final datos = await img.toByteData(format: ui.ImageByteFormat.png);
  return datos!.buffer.asUint8List();
}
