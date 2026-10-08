// Capas comunes de los mapas 3D (MapLibre): edificios, rutas, viaje, casetas, semáforos,
// combis, pines y etiquetas. Cada pantalla sólo cambia los datos con setGeoJsonSource.

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
  await c.addFillExtrusionLayer('semaforos', 'semaforos-3d', extrusion);
  await c.addFillExtrusionLayer('combis', 'combis-3d', extrusion);
  await c.addFillExtrusionLayer('pines', 'pines-3d', extrusion);
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
      textOffset: [0, -1.6],
      textAllowOverlap: false,
      textIgnorePlacement: false,
      symbolSortKey: ['get', 'prioridad'],
      textMaxWidth: 14,
    ),
  );
}
